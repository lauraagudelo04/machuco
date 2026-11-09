// Bloqueo por estado de cuenta en firestore.rules. Las operaciones que exigen
// una cuenta activa (isActiveOwner / isActiveClient) están en `payments`;
// `users` solo restringe por rol y por autor. Ejecutar con
// `npm run test:emulator` (proyecto ficticio demo-machuco).
import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, test } from 'node:test';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  doc,
  getDoc,
  serverTimestamp,
  setDoc,
  Timestamp,
  updateDoc,
} from 'firebase/firestore';

let env;

const user = (role, accountStatus) => {
  const data = {
    fullName: `Usuario ${role}`,
    email: `${role}-${accountStatus ?? 'sin-estado'}@example.com`,
    phoneNumber: '+573001234567',
    role,
    createdAt: Timestamp.now(),
  };
  if (accountStatus !== undefined) data.accountStatus = accountStatus;
  return data;
};

const users = {
  ownerActive: user('owner', 'active'),
  ownerPending: user('owner', 'pending_approval'),
  ownerRejected: user('owner', 'rejected'),
  ownerDisabled: user('owner', 'disabled'),
  clientActive: user('client', 'active'),
  clientDisabled: user('client', 'disabled'),
  adminActive: user('admin', 'active'),
  adminNoStatus: user('admin', undefined),
  adminDisabled: user('admin', 'disabled'),
};

const as = (uid) =>
  env
    .authenticatedContext(uid, { email: users[uid]?.email, email_verified: true })
    .firestore();

/// Pago válido según hasValidPaymentFields.
const payment = (ownerId, overrides = {}) => ({
  ownerId,
  bookingId: 'booking-1',
  bookingReference: 'RES-0001',
  clientId: 'clientActive',
  client: 'Cliente Uno',
  motelId: 'motel-1',
  motel: 'Motel Uno',
  roomId: 'room-1',
  room: 'Suite',
  reservationDate: Timestamp.fromDate(new Date('2026-11-10T20:00:00Z')),
  amount: 85000,
  status: 'pending',
  updatedAt: serverTimestamp(),
  ...overrides,
});

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-machuco',
    firestore: {
      rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8'),
    },
  });
});

after(async () => {
  await env?.cleanup();
});

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    for (const [uid, data] of Object.entries(users)) {
      await setDoc(doc(db, `users/${uid}`), data);
    }
    for (const ownerId of [
      'ownerActive',
      'ownerPending',
      'ownerRejected',
      'ownerDisabled',
    ]) {
      await setDoc(doc(db, `payments/pay-${ownerId}`), {
        ...payment(ownerId),
        updatedAt: Timestamp.now(),
      });
    }
  });
});

describe('propietario según su estado', () => {
  test('[EST-01] activo lee y confirma sus pagos', async () => {
    await assertSucceeds(getDoc(doc(as('ownerActive'), 'payments/pay-ownerActive')));
    await assertSucceeds(
      updateDoc(doc(as('ownerActive'), 'payments/pay-ownerActive'), {
        status: 'cancelled',
        updatedAt: serverTimestamp(),
      }),
    );
  });

  for (const uid of ['ownerPending', 'ownerRejected', 'ownerDisabled']) {
    test(`[EST-02] ${uid} no lee, crea ni confirma pagos`, async () => {
      await assertFails(getDoc(doc(as(uid), `payments/pay-${uid}`)));
      await assertFails(setDoc(doc(as(uid), `payments/new-${uid}`), payment(uid)));
      await assertFails(
        updateDoc(doc(as(uid), `payments/pay-${uid}`), {
          status: 'cancelled',
          updatedAt: serverTimestamp(),
        }),
      );
    });
  }
});

describe('cliente según su estado', () => {
  test('[EST-03] activo crea su pago pendiente', async () => {
    await assertSucceeds(
      setDoc(
        doc(as('clientActive'), 'payments/new-client'),
        payment('ownerActive'),
      ),
    );
  });

  test('[EST-04] deshabilitado no crea pagos', async () => {
    await assertFails(
      setDoc(
        doc(as('clientDisabled'), 'payments/new-client'),
        payment('ownerActive', { clientId: 'clientDisabled' }),
      ),
    );
  });
});

describe('administrador según su estado', () => {
  test('[EST-05] activo lee perfiles y pagos', async () => {
    await assertSucceeds(getDoc(doc(as('adminActive'), 'users/clientActive')));
    await assertSucceeds(getDoc(doc(as('adminActive'), 'payments/pay-ownerActive')));
  });

  for (const uid of ['adminNoStatus', 'adminDisabled']) {
    test(`[EST-06] ${uid} no aprueba, rechaza ni deshabilita`, async () => {
      await assertFails(
        updateDoc(doc(as(uid), 'users/ownerPending'), {
          accountStatus: 'active',
          approvedBy: uid,
          approvedAt: serverTimestamp(),
        }),
      );
      await assertFails(
        updateDoc(doc(as(uid), 'users/clientActive'), { accountStatus: 'disabled' }),
      );
    });

    // HALLAZGO: isAdmin() (lectura) no exige accountStatus == 'active'; un
    // admin deshabilitado o sin estado sigue leyendo todos los perfiles y
    // pagos. Se deja asentado el comportamiento actual (no se cambió la
    // regla de producción sin aprobación).
    test(`[EST-07] HALLAZGO: ${uid} todavía puede leer perfiles y pagos`, async () => {
      await assertSucceeds(getDoc(doc(as(uid), 'users/clientActive')));
      await assertSucceeds(getDoc(doc(as(uid), 'payments/pay-ownerActive')));
    });
  }
});

describe('perfil propio según su estado', () => {
  // HALLAZGO: la regla de `update` propio no mira accountStatus; un usuario
  // deshabilitado o rechazado puede cambiar su nombre y celular. Solo puede
  // tocar esos dos campos (nunca rol ni estado).
  for (const uid of ['ownerRejected', 'clientDisabled']) {
    test(`[EST-08] HALLAZGO: ${uid} puede editar nombre y celular, pero no su estado`, async () => {
      await assertSucceeds(
        updateDoc(doc(as(uid), `users/${uid}`), { fullName: 'Nombre Nuevo' }),
      );
      await assertFails(
        updateDoc(doc(as(uid), `users/${uid}`), { accountStatus: 'active' }),
      );
    });
  }
});
