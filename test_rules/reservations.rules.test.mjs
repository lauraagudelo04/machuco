// Pruebas de firestore.rules (colección reservations) contra el emulador de
// Firestore. Cubren el caso que rompió la sincronización el 2026-11-09: un
// despliegue sin el bloque `match /reservations` deja la colección denegada.
// Ejecutar con `npm run test:emulator` (proyecto ficticio demo-machuco).
import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, test } from 'node:test';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  collection,
  doc,
  getDoc,
  getDocs,
  query,
  serverTimestamp,
  setDoc,
  Timestamp,
  updateDoc,
  where,
} from 'firebase/firestore';

let env;

const user = (role, accountStatus = 'active') => ({
  fullName: `Usuario ${role}`,
  email: `${role}@example.com`,
  phoneNumber: '+573001234567',
  role,
  accountStatus,
  createdAt: Timestamp.now(),
});

const users = {
  client: user('client'),
  otherClient: user('client'),
  owner: user('owner'),
  otherOwner: user('owner'),
  admin: user('admin'),
};

const as = (uid) =>
  env
    .authenticatedContext(uid, { email: users[uid]?.email, email_verified: true })
    .firestore();

/// Reserva válida según hasValidReservationFields.
const reservation = (overrides = {}) => ({
  ownerId: 'owner',
  guestId: 'client',
  guestName: 'Cliente Uno',
  requestId: 'request-1',
  motelId: '1',
  motelName: 'Motel Uno',
  roomId: 'room-1',
  roomName: 'Suite',
  roomNumber: '101',
  checkIn: Timestamp.fromDate(new Date('2026-11-10T20:00:00Z')),
  checkOut: Timestamp.fromDate(new Date('2026-11-10T23:00:00Z')),
  stayMode: 'dateTimeRange',
  guestCount: 2,
  services: [],
  products: [],
  roomTotal: 120000,
  total: 148000,
  status: 'pending',
  createdAt: Timestamp.fromDate(new Date('2026-11-09T18:00:00Z')),
  invoiceAccessStatus: 'notApplicable',
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
    await setDoc(doc(db, 'reservations/r-existing'), {
      ...reservation(),
      updatedAt: Timestamp.now(),
    });
  });
});

describe('crear reservas', () => {
  test('[RES-01] el cliente crea una reserva a su nombre', async () => {
    await assertSucceeds(
      setDoc(doc(as('client'), 'reservations/r-new'), reservation()),
    );
  });

  test('[RES-02] el cliente no crea reservas a nombre de otro', async () => {
    await assertFails(
      setDoc(
        doc(as('client'), 'reservations/r-new'),
        reservation({ guestId: 'otherClient' }),
      ),
    );
  });

  test('[RES-03] el propietario no crea reservas', async () => {
    await assertFails(
      setDoc(
        doc(as('owner'), 'reservations/r-new'),
        reservation({ guestId: 'owner', ownerId: 'otherOwner' }),
      ),
    );
  });
});

describe('leer reservas', () => {
  test('[RES-04] cliente, propietario del motel y admin la leen', async () => {
    for (const uid of ['client', 'owner', 'admin']) {
      await assertSucceeds(getDoc(doc(as(uid), 'reservations/r-existing')));
    }
  });

  test('[RES-05] otro cliente u otro propietario no la leen', async () => {
    for (const uid of ['otherClient', 'otherOwner']) {
      await assertFails(getDoc(doc(as(uid), 'reservations/r-existing')));
    }
  });

  test('[RES-06] el cliente lista sus reservas por guestId', async () => {
    await assertSucceeds(
      getDocs(
        query(
          collection(as('client'), 'reservations'),
          where('guestId', '==', 'client'),
        ),
      ),
    );
  });
});

describe('cambiar el estado', () => {
  test('[RES-07] el cliente no acredita un sandbox, pero puede cancelar', async () => {
    const ref = doc(as('client'), 'reservations/r-existing');
    await assertFails(
      updateDoc(ref, {
        status: 'upcoming',
        paymentMethod: 'Tarjeta',
        updatedAt: serverTimestamp(),
      }),
    );
    await assertSucceeds(
      updateDoc(ref, {
        status: 'cancelled',
        cancellationReason: 'Cambio de planes',
        updatedAt: serverTimestamp(),
      }),
    );
  });

  test('[RES-08] nadie cambia el valor de la reserva', async () => {
    await assertFails(
      updateDoc(doc(as('client'), 'reservations/r-existing'), {
        total: 1000,
        updatedAt: serverTimestamp(),
      }),
    );
  });
});
