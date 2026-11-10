// Contrato de FirestoreAdminAccessRepository contra el emulador.
//
// `flutter test` no puede cargar el plugin nativo de Firestore y no hay
// entorno de integración (Visual Studio o dispositivo), así que aquí se
// reproducen con el SDK web, línea por línea, la consulta y la transacción de
// lib/database/repository/auth/admin_access_repository.dart. Si el repositorio
// cambia su consulta o sus escrituras, estas funciones deben actualizarse.
import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, test } from 'node:test';
import assert from 'node:assert/strict';
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
  limit,
  orderBy,
  query,
  runTransaction,
  serverTimestamp,
  setDoc,
  Timestamp,
  updateDoc,
  where,
} from 'firebase/firestore';

const ALREADY_HANDLED = 'La solicitud ya fue atendida';
let env;

// ---- Réplica de FirestoreAdminAccessRepository ----------------------------

/// listPendingOwners()
const listPendingOwners = (db) =>
  getDocs(
    query(
      collection(db, 'users'),
      where('role', '==', 'owner'),
      where('accountStatus', '==', 'pending_approval'),
      orderBy('createdAt'),
      limit(100),
    ),
  );

/// _resolve(): transacción que solo actúa si sigue pendiente.
const resolve = (db, uid, changes) =>
  runTransaction(db, async (tx) => {
    const ref = doc(db, `users/${uid}`);
    const snapshot = await tx.get(ref);
    const data = snapshot.data();
    const isPending =
      snapshot.exists() &&
      data?.accountStatus === 'pending_approval' &&
      data?.role === 'owner';
    if (!isPending) throw new Error(ALREADY_HANDLED);
    tx.update(ref, changes);
  });

const approveOwner = (db, uid, adminUid) =>
  resolve(db, uid, {
    accountStatus: 'active',
    approvedBy: adminUid,
    approvedAt: serverTimestamp(),
  });

const rejectOwner = (db, uid, adminUid, reason) => {
  const trimmed = reason.trim();
  if (trimmed.length < 10 || trimmed.length > 300) {
    return Promise.reject(new Error('El motivo debe tener entre 10 y 300 caracteres.'));
  }
  return resolve(db, uid, {
    accountStatus: 'rejected',
    rejectionReason: trimmed,
    rejectedBy: adminUid,
    rejectedAt: serverTimestamp(),
  });
};

// ---- Datos -----------------------------------------------------------------

const profile = (role, accountStatus, createdAt, extra = {}) => {
  const data = {
    fullName: `Usuario ${role}`,
    email: `${role}@example.com`,
    phoneNumber: '+573001234567',
    role,
    createdAt: Timestamp.fromDate(new Date(createdAt)),
    ...extra,
  };
  if (accountStatus !== undefined) data.accountStatus = accountStatus;
  return data;
};

/// Lee un perfil sin reglas (withSecurityRulesDisabled no devuelve valor).
const readProfile = async (uid) => {
  let data;
  await env.withSecurityRulesDisabled(async (ctx) => {
    data = (await getDoc(doc(ctx.firestore(), `users/${uid}`))).data();
  });
  return data;
};

const as = (uid) =>
  env.authenticatedContext(uid, { email: `${uid}@example.com` }).firestore();

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
    const seed = {
      admin1: profile('admin', 'active', '2026-01-01'),
      admin2: profile('admin', 'active', '2026-01-02'),
      adminNoStatus: profile('admin', undefined, '2026-01-03'),
      client: profile('client', 'active', '2026-01-04'),
      ownerNew: profile('owner', 'pending_approval', '2026-03-01', {
        personType: 'natural',
        nit: '1020304050-8',
      }),
      ownerOld: profile('owner', 'pending_approval', '2026-02-01', {
        personType: 'juridica',
        nit: '900123456-8',
        companyName: 'Inversiones Ejemplo S.A.S.',
      }),
      ownerActive: profile('owner', 'active', '2026-01-15'),
    };
    for (const [uid, data] of Object.entries(seed)) {
      await setDoc(doc(db, `users/${uid}`), data);
    }
  });
});

describe('listPendingOwners', () => {
  test('[ADM-01] un admin activo lista solo pendientes, del más antiguo al más reciente', async () => {
    const snapshot = await assertSucceeds(listPendingOwners(as('admin1')));
    assert.deepEqual(
      snapshot.docs.map((d) => d.id),
      ['ownerOld', 'ownerNew'],
    );
  });

  test('[ADM-02] un cliente o un visitante no pueden listar solicitudes', async () => {
    await assertFails(listPendingOwners(as('client')));
    await assertFails(listPendingOwners(env.unauthenticatedContext().firestore()));
  });

  test('[ADM-03] HALLAZGO: un admin sin accountStatus sí puede listar (isAdmin no exige estado)', async () => {
    await assertSucceeds(listPendingOwners(as('adminNoStatus')));
  });
});

describe('approveOwner / rejectOwner', () => {
  test('[ADM-04] aprobar deja la cuenta activa con auditoría del admin', async () => {
    await assertSucceeds(approveOwner(as('admin1'), 'ownerOld', 'admin1'));

    const stored = await readProfile('ownerOld');
    assert.equal(stored.accountStatus, 'active');
    assert.equal(stored.approvedBy, 'admin1');
    assert.ok(stored.approvedAt instanceof Timestamp);
  });

  test('[ADM-05] rechazar guarda el motivo recortado y la auditoría', async () => {
    await assertSucceeds(
      rejectOwner(as('admin1'), 'ownerNew', 'admin1', '  El NIT no coincide con la razón social  '),
    );
    const stored = await readProfile('ownerNew');
    assert.equal(stored.accountStatus, 'rejected');
    assert.equal(stored.rejectionReason, 'El NIT no coincide con la razón social');
    assert.equal(stored.rejectedBy, 'admin1');
  });

  test('[ADM-06] un motivo corto se rechaza antes de escribir', async () => {
    await assert.rejects(rejectOwner(as('admin1'), 'ownerNew', 'admin1', 'corto'));
  });

  test('[ADM-07] la segunda decisión informa "ya fue atendida" y las reglas la bloquean', async () => {
    await assertSucceeds(approveOwner(as('admin1'), 'ownerOld', 'admin1'));

    await assert.rejects(
      rejectOwner(as('admin2'), 'ownerOld', 'admin2', 'Motivo suficientemente largo'),
      { message: ALREADY_HANDLED },
    );
    // Aunque la app se saltara la comprobación, la regla no lo permite.
    await assertFails(
      updateDoc(doc(as('admin2'), 'users/ownerOld'), {
        accountStatus: 'rejected',
        rejectionReason: 'Motivo suficientemente largo',
        rejectedBy: 'admin2',
        rejectedAt: serverTimestamp(),
      }),
    );
  });

  test('[ADM-08] dos administradores a la vez: solo una decisión gana', async () => {
    const results = await Promise.allSettled([
      approveOwner(as('admin1'), 'ownerOld', 'admin1'),
      rejectOwner(as('admin2'), 'ownerOld', 'admin2', 'Documentación incompleta'),
    ]);
    assert.equal(results.filter((r) => r.status === 'fulfilled').length, 1);
  });

  test('[ADM-09] un admin sin accountStatus no puede aprobar', async () => {
    await assertFails(approveOwner(as('adminNoStatus'), 'ownerOld', 'adminNoStatus'));
  });

  test('[ADM-10] un cliente no puede aprobar', async () => {
    await assertFails(approveOwner(as('client'), 'ownerOld', 'client'));
  });

  test('[ADM-11] no se puede "aprobar" a quien ya está activo ni a un cliente', async () => {
    await assert.rejects(approveOwner(as('admin1'), 'ownerActive', 'admin1'), {
      message: ALREADY_HANDLED,
    });
    await assert.rejects(approveOwner(as('admin1'), 'client', 'admin1'), {
      message: ALREADY_HANDLED,
    });
  });
});
