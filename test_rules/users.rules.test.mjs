// Pruebas de firestore.rules (colección users) contra el emulador de Firestore.
// Se ejecutan con `npm run test:emulator` desde test_rules/ (ver
// docs/auth/android-setup.md). Usan el proyecto ficticio `demo-machuco`: nunca
// tocan el proyecto real.
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, test } from 'node:test';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  deleteDoc,
  doc,
  getDoc,
  serverTimestamp,
  setDoc,
  runTransaction,
  Timestamp,
  updateDoc,
  writeBatch,
} from 'firebase/firestore';

const PROJECT_ID = 'demo-machuco';
let env;

const emails = {
  client: 'cliente@example.com',
  owner: 'propietario@example.com',
  admin: 'admin@example.com',
  legacyAdmin: 'admin-sin-estado@example.com',
  other: 'otro@example.com',
};

/// Contexto autenticado con el correo en el token (la regla lo compara).
const as = (uid, email = emails[uid] ?? `${uid}@example.com`) =>
  env.authenticatedContext(uid, { email, email_verified: true }).firestore();
const anonymous = () => env.unauthenticatedContext().firestore();

const clientProfile = (overrides = {}) => ({
  fullName: 'Ana Pérez',
  email: emails.client,
  phoneNumber: '+573001234567',
  role: 'client',
  accountStatus: 'active',
  createdAt: serverTimestamp(),
  firstNames: 'Ana',
  lastNames: 'Pérez',
  phoneCountryCodeId: 1,
  birthDate: Timestamp.fromDate(new Date('1995-05-10T00:00:00Z')),
  ...overrides,
});

const ownerProfile = (overrides = {}) => ({
  fullName: 'Inversiones Ejemplo',
  email: emails.owner,
  phoneNumber: '+573001112233',
  role: 'owner',
  accountStatus: 'pending_approval',
  createdAt: serverTimestamp(),
  personType: 'juridica',
  nit: '900123456-8',
  companyName: 'Inversiones Ejemplo S.A.S.',
  planId: 1,
  ...overrides,
});

/// Siembra documentos sin pasar por las reglas.
async function seed(docs) {
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    for (const [path, data] of Object.entries(docs)) {
      await setDoc(doc(db, path), data);
    }
  });
}

const seededAdmin = {
  fullName: 'Admin Uno',
  email: emails.admin,
  phoneNumber: '+573009998877',
  role: 'admin',
  accountStatus: 'active',
  createdAt: Timestamp.now(),
};

before(async () => {
  env = await initializeTestEnvironment({
    projectId: PROJECT_ID,
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
});

describe('users: lectura', () => {
  beforeEach(async () => {
    await seed({
      'users/client': { ...clientProfile(), createdAt: Timestamp.now() },
      'users/admin': seededAdmin,
    });
  });

  test('sin sesión no se puede leer un perfil', async () => {
    await assertFails(getDoc(doc(anonymous(), 'users/client')));
  });

  test('el usuario lee su propio perfil', async () => {
    await assertSucceeds(getDoc(doc(as('client'), 'users/client')));
  });

  test('un usuario no lee el perfil de otro', async () => {
    await assertFails(getDoc(doc(as('other'), 'users/client')));
  });

  test('un admin lee cualquier perfil', async () => {
    await assertSucceeds(getDoc(doc(as('admin'), 'users/client')));
  });
});

describe('users: registro público', () => {
  test('sin sesión no se puede crear un perfil', async () => {
    await assertFails(setDoc(doc(anonymous(), 'users/client'), clientProfile()));
  });

  test('cliente activo con datos válidos', async () => {
    await assertSucceeds(setDoc(doc(as('client'), 'users/client'), clientProfile()));
  });

  test('propietario pendiente con tipo de persona y NIT', async () => {
    await assertSucceeds(setDoc(doc(as('owner'), 'users/owner'), ownerProfile()));
  });

  test('nadie se registra como admin', async () => {
    await assertFails(
      setDoc(doc(as('client'), 'users/client'), clientProfile({ role: 'admin' })),
    );
  });

  test('un cliente no puede nacer pendiente ni un propietario activo', async () => {
    await assertFails(
      setDoc(
        doc(as('client'), 'users/client'),
        clientProfile({ accountStatus: 'pending_approval' }),
      ),
    );
    await assertFails(
      setDoc(doc(as('owner'), 'users/owner'), ownerProfile({ accountStatus: 'active' })),
    );
  });

  test('no se crea el perfil de otro uid', async () => {
    await assertFails(setDoc(doc(as('client'), 'users/otro-uid'), clientProfile()));
  });

  test('el correo debe ser el del token', async () => {
    await assertFails(
      setDoc(
        doc(as('client'), 'users/client'),
        clientProfile({ email: 'suplantado@example.com' }),
      ),
    );
  });

  test('sin correo en el token no se crea el perfil (p. ej. GitHub privado)', async () => {
    const db = env.authenticatedContext('client', {}).firestore();
    await assertFails(setDoc(doc(db, 'users/client'), clientProfile()));
  });

  test('[SOC-14] un usuario de Google completa su perfil sin cambios en las reglas', async () => {
    const db = env
      .authenticatedContext('google-user', {
        email: emails.client,
        email_verified: true,
        firebase: { sign_in_provider: 'google.com' },
      })
      .firestore();
    await assertSucceeds(setDoc(doc(db, 'users/google-user'), clientProfile()));
    await assertFails(
      setDoc(doc(db, 'users/google-user'), clientProfile({ role: 'admin' })),
    );
  });

  test('createdAt debe ser la hora del servidor', async () => {
    await assertFails(
      setDoc(
        doc(as('client'), 'users/client'),
        clientProfile({ createdAt: Timestamp.fromDate(new Date('2020-01-01')) }),
      ),
    );
  });

  test('un cliente menor de edad es rechazado', async () => {
    const tenYearsAgo = new Date();
    tenYearsAgo.setFullYear(tenYearsAgo.getFullYear() - 10);
    await assertFails(
      setDoc(
        doc(as('client'), 'users/client'),
        clientProfile({ birthDate: Timestamp.fromDate(tenYearsAgo) }),
      ),
    );
  });

  test('un cliente no trae campos de propietario', async () => {
    await assertFails(
      setDoc(doc(as('client'), 'users/client'), clientProfile({ nit: '900123456-8' })),
    );
  });

  test('un propietario sin NIT o con NIT mal formado es rechazado', async () => {
    const { nit: _omit, ...withoutNit } = ownerProfile();
    await assertFails(setDoc(doc(as('owner'), 'users/owner'), withoutNit));
    await assertFails(
      setDoc(doc(as('owner'), 'users/owner'), ownerProfile({ nit: "1' OR '1'='1" })),
    );
  });

  test('razón social solo para persona jurídica', async () => {
    await assertFails(
      setDoc(doc(as('owner'), 'users/owner'), ownerProfile({ personType: 'natural' })),
    );
  });

  test('no se aceptan campos fuera de la lista permitida', async () => {
    await assertFails(
      setDoc(doc(as('client'), 'users/client'), clientProfile({ isSuperUser: true })),
    );
  });
});

describe('users: actualización por el propio usuario', () => {
  beforeEach(async () => {
    await seed({ 'users/client': { ...clientProfile(), createdAt: Timestamp.now() } });
  });

  test('puede cambiar su nombre y su celular', async () => {
    await assertSucceeds(
      updateDoc(doc(as('client'), 'users/client'), {
        fullName: 'Ana María Pérez',
        phoneNumber: '+573001230000',
      }),
    );
  });

  test('no puede cambiar su rol ni su estado', async () => {
    await assertFails(updateDoc(doc(as('client'), 'users/client'), { role: 'admin' }));
    await assertFails(
      updateDoc(doc(as('client'), 'users/client'), { accountStatus: 'disabled' }),
    );
  });

  test('otro usuario no puede modificarlo', async () => {
    await assertFails(
      updateDoc(doc(as('other'), 'users/client'), { fullName: 'Intruso Malo' }),
    );
  });
});

describe('users: decisiones del administrador', () => {
  beforeEach(async () => {
    await seed({
      'users/admin': seededAdmin,
      'users/owner': { ...ownerProfile(), createdAt: Timestamp.now() },
      'users/client': { ...clientProfile(), createdAt: Timestamp.now() },
      'users/admin2': { ...seededAdmin, email: 'admin2@example.com' },
    });
    // `undefined` no es válido en Firestore: se siembra sin el campo.
    await env.withSecurityRulesDisabled(async (ctx) => {
      const { accountStatus: _omit, ...legacy } = seededAdmin;
      await setDoc(doc(ctx.firestore(), 'users/legacyAdmin'), {
        ...legacy,
        email: emails.legacyAdmin,
      });
    });
  });

  const approve = (db) =>
    updateDoc(doc(db, 'users/owner'), {
      accountStatus: 'active',
      approvedBy: 'admin',
      approvedAt: serverTimestamp(),
    });

  test('un admin activo aprueba un propietario pendiente', async () => {
    await assertSucceeds(approve(as('admin')));
  });

  test('un admin sin accountStatus no puede aprobar', async () => {
    const db = as('legacyAdmin');
    await assertFails(
      updateDoc(doc(db, 'users/owner'), {
        accountStatus: 'active',
        approvedBy: 'legacyAdmin',
        approvedAt: serverTimestamp(),
      }),
    );
  });

  test('un cliente no puede aprobar', async () => {
    await assertFails(
      updateDoc(doc(as('client'), 'users/owner'), {
        accountStatus: 'active',
        approvedBy: 'client',
        approvedAt: serverTimestamp(),
      }),
    );
  });

  test('la segunda decisión sobre la misma solicitud se rechaza', async () => {
    await assertSucceeds(approve(as('admin')));
    await assertFails(
      updateDoc(doc(as('admin'), 'users/owner'), {
        accountStatus: 'rejected',
        rejectionReason: 'Documentación incompleta del NIT',
        rejectedBy: 'admin',
        rejectedAt: serverTimestamp(),
      }),
    );
  });

  test('rechazar exige un motivo de 10 a 300 caracteres', async () => {
    await assertFails(
      updateDoc(doc(as('admin'), 'users/owner'), {
        accountStatus: 'rejected',
        rejectionReason: 'corto',
        rejectedBy: 'admin',
        rejectedAt: serverTimestamp(),
      }),
    );
    await assertSucceeds(
      updateDoc(doc(as('admin'), 'users/owner'), {
        accountStatus: 'rejected',
        rejectionReason: 'El NIT no coincide con la razón social',
        rejectedBy: 'admin',
        rejectedAt: serverTimestamp(),
      }),
    );
  });

  test('la auditoría debe ser del admin que decide', async () => {
    await assertFails(
      updateDoc(doc(as('admin'), 'users/owner'), {
        accountStatus: 'active',
        approvedBy: 'otro-admin',
        approvedAt: serverTimestamp(),
      }),
    );
  });

  test('un admin nunca cambia el rol', async () => {
    await assertFails(updateDoc(doc(as('admin'), 'users/client'), { role: 'owner' }));
    await assertFails(
      updateDoc(doc(as('admin'), 'users/owner'), {
        accountStatus: 'active',
        approvedBy: 'admin',
        approvedAt: serverTimestamp(),
        role: 'admin',
      }),
    );
  });

  test('un admin deshabilita y rehabilita a un cliente', async () => {
    await assertSucceeds(
      updateDoc(doc(as('admin'), 'users/client'), { accountStatus: 'disabled' }),
    );
    await assertSucceeds(
      updateDoc(doc(as('admin'), 'users/client'), { accountStatus: 'active' }),
    );
  });

  test('un admin no deshabilita a otro admin', async () => {
    await assertFails(
      updateDoc(doc(as('admin'), 'users/admin2'), { accountStatus: 'disabled' }),
    );
  });
});

describe('users: eliminación', () => {
  beforeEach(async () => {
    await seed({
      'users/client': { ...clientProfile(), createdAt: Timestamp.now() },
      'users/admin': seededAdmin,
      'users/owner': { ...ownerProfile(), createdAt: Timestamp.now() },
      'users/admin2': { ...seededAdmin, email: 'admin2@example.com' },
      'users/disabledAdmin': { ...seededAdmin, accountStatus: 'disabled' },
      'users/temporaryAdmin': { ...seededAdmin, mustChangePassword: true },
    });
  });

  test('el usuario elimina su propio perfil', async () => {
    await assertSucceeds(deleteDoc(doc(as('client'), 'users/client')));
  });

  test('un usuario sin autoridad no elimina el perfil de otro', async () => {
    await assertFails(deleteDoc(doc(as('other'), 'users/client')));
    await assertFails(deleteDoc(doc(as('client'), 'users/owner')));
    await assertFails(deleteDoc(doc(as('owner'), 'users/client')));
  });


  test('el admin activo ya no elimina perfiles: se anonimizan', async () => {
    await assertFails(deleteDoc(doc(as('admin'), 'users/client')));
    await assertFails(deleteDoc(doc(as('admin'), 'users/owner')));
  });

  test('el admin activo no elimina a otro administrador', async () => {
    await assertFails(deleteDoc(doc(as('admin'), 'users/admin2')));
  });

  for (const uid of ['disabledAdmin', 'temporaryAdmin']) {
    test(`${uid} no elimina perfiles ajenos`, async () => {
      await assertFails(deleteDoc(doc(as(uid), 'users/client')));
      await assertFails(deleteDoc(doc(as(uid), 'users/owner')));
    });
  }

  test('sin sesión no se elimina nada', async () => {
    await assertFails(deleteDoc(doc(anonymous(), 'users/client')));
  });

  test('un admin no borra su propio perfil (se anonimiza)', async () => {
    await assertFails(deleteDoc(doc(as('admin'), 'users/admin')));
  });
});

// ---------------------------------------------------------------------------
// Gestión de administradores: sin backend, la autoridad son estas reglas.
// ---------------------------------------------------------------------------

const fixedCreatedAt = Timestamp.fromDate(new Date('2026-01-01T00:00:00Z'));
const registryPath = 'system/adminRegistry';

/// Administrador activo ya sembrado (contraseña definida).
const adminDoc = (email, overrides = {}) => ({
  fullName: 'Admin Prueba',
  email,
  phoneNumber: '+573009998877',
  role: 'admin',
  accountStatus: 'active',
  createdAt: fixedCreatedAt,
  firstNames: 'Admin',
  lastNames: 'Prueba',
  phoneCountryCodeId: 1,
  ...overrides,
});

/// Perfil que escribe un admin al crear a otro (contraseña temporal).
const newAdminProfile = (creator, overrides = {}) => ({
  fullName: 'Nuevo Admin',
  email: 'nuevo@example.com',
  phoneNumber: '+573001112233',
  role: 'admin',
  accountStatus: 'active',
  createdAt: serverTimestamp(),
  firstNames: 'Nuevo',
  lastNames: 'Admin',
  phoneCountryCodeId: 1,
  mustChangePassword: true,
  createdBy: creator,
  ...overrides,
});

/// Documento resultante de anonimizar (sin datos personales).
const anonymizedDoc = (actor, overrides = {}) => ({
  fullName: 'Administrador eliminado',
  role: 'admin',
  accountStatus: 'anonymized',
  createdAt: fixedCreatedAt,
  anonymizedAt: serverTimestamp(),
  anonymizedBy: actor,
  ...overrides,
});

const seedRegistry = (count) => seed({ [registryPath]: { activeAdminCount: count } });

/// Lote equivalente a la transacción de la app al crear un admin.
async function createAdminBatch(db, creator, uid, profile, nextCount) {
  const batch = writeBatch(db);
  batch.set(doc(db, `users/${uid}`), profile);
  batch.update(doc(db, registryPath), { activeAdminCount: nextCount });
  await batch.commit();
}

/// Lote equivalente a la transacción de la app al anonimizar un admin.
async function anonymizeBatch(db, actor, uid, nextCount, docOverrides = {}) {
  const batch = writeBatch(db);
  batch.set(doc(db, `users/${uid}`), anonymizedDoc(actor, docOverrides));
  batch.update(doc(db, registryPath), { activeAdminCount: nextCount });
  await batch.commit();
}

describe('administradores: crear', () => {
  beforeEach(async () => {
    await seed({
      'users/admin': adminDoc(emails.admin),
      'users/client': { ...clientProfile(), createdAt: Timestamp.now() },
      'users/pendingAdmin': adminDoc('pendiente@example.com', { mustChangePassword: true }),
    });
    await seedRegistry(1);
  });

  test('un admin activo crea otro admin y suma 1 al registro', async () => {
    await assertSucceeds(
      createAdminBatch(as('admin'), 'admin', 'nuevo', newAdminProfile('admin'), 2),
    );
  });

  test('sin sumar 1 al registro (o sumando más) se rechaza', async () => {
    const db = as('admin');
    await assertFails(
      setDoc(doc(db, 'users/nuevo'), newAdminProfile('admin')),
    );
    await assertFails(
      createAdminBatch(db, 'admin', 'nuevo', newAdminProfile('admin'), 1),
    );
    await assertFails(
      createAdminBatch(db, 'admin', 'nuevo', newAdminProfile('admin'), 3),
    );
  });

  test('un cliente no crea administradores', async () => {
    await assertFails(
      createAdminBatch(as('client'), 'client', 'nuevo', newAdminProfile('client'), 2),
    );
  });

  test('un admin con contraseña temporal pendiente no crea administradores', async () => {
    await assertFails(
      createAdminBatch(
        as('pendingAdmin'),
        'pendingAdmin',
        'nuevo',
        newAdminProfile('pendingAdmin'),
        2,
      ),
    );
  });

  test('el nuevo admin nace activo, con contraseña temporal y auditado', async () => {
    const db = as('admin');
    const attempts = [
      { mustChangePassword: false },
      { accountStatus: 'pending_approval' },
      { role: 'owner' },
      { createdBy: 'otro-admin' },
      { createdAt: Timestamp.fromDate(new Date('2020-01-01')) },
      { isSuperUser: true },
      { email: 'no-es-un-correo' },
      { fullName: 'A' },
    ];
    for (const overrides of attempts) {
      await assertFails(
        createAdminBatch(db, 'admin', 'nuevo', newAdminProfile('admin', overrides), 2),
      );
    }
  });

  test('nadie crea un admin sobre un perfil que ya existe', async () => {
    await assertFails(
      createAdminBatch(as('admin'), 'admin', 'client', newAdminProfile('admin'), 2),
    );
  });

  test('el registro solo cambia en +-1 y nunca baja de 1', async () => {
    const db = as('admin');
    await assertFails(updateDoc(doc(db, registryPath), { activeAdminCount: 3 }));
    await assertFails(updateDoc(doc(db, registryPath), { activeAdminCount: 0 }));
    await assertFails(updateDoc(doc(as('client'), registryPath), { activeAdminCount: 2 }));
    await assertSucceeds(updateDoc(doc(db, registryPath), { activeAdminCount: 2 }));
  });

  test('el registro solo lo lee un admin activo y nadie lo borra', async () => {
    await assertSucceeds(getDoc(doc(as('admin'), registryPath)));
    await assertFails(getDoc(doc(as('client'), registryPath)));
    await assertFails(getDoc(doc(as('pendingAdmin'), registryPath)));
    await assertFails(deleteDoc(doc(as('admin'), registryPath)));
  });

  test('el primer registro lo crea un admin activo con conteo >= 1', async () => {
    await env.clearFirestore();
    await seed({ 'users/admin': adminDoc(emails.admin) });
    await assertFails(setDoc(doc(as('admin'), registryPath), { activeAdminCount: 0 }));
    await assertFails(setDoc(doc(as('client'), registryPath), { activeAdminCount: 1 }));
    await assertSucceeds(setDoc(doc(as('admin'), registryPath), { activeAdminCount: 1 }));
  });
});

describe('administradores: editar', () => {
  beforeEach(async () => {
    await seed({
      'users/admin': adminDoc(emails.admin),
      'users/admin2': adminDoc('admin2@example.com'),
      'users/gone': anonymizedDoc('admin', { anonymizedAt: Timestamp.now() }),
      'users/client': { ...clientProfile(), createdAt: Timestamp.now() },
    });
    await seedRegistry(2);
  });

  const contact = {
    firstNames: 'Otro',
    lastNames: 'Nombre',
    fullName: 'Otro Nombre',
    phoneCountryCodeId: 2,
    phoneNumber: '+541112223344',
  };

  test('un admin activo edita el contacto de otro admin', async () => {
    await assertSucceeds(updateDoc(doc(as('admin'), 'users/admin2'), contact));
  });

  test('nunca cambia el correo, el rol ni el estado de otro admin', async () => {
    const db = as('admin');
    await assertFails(updateDoc(doc(db, 'users/admin2'), { email: 'nuevo@example.com' }));
    await assertFails(updateDoc(doc(db, 'users/admin2'), { role: 'client' }));
    await assertFails(updateDoc(doc(db, 'users/admin2'), { accountStatus: 'disabled' }));
    await assertFails(updateDoc(doc(db, 'users/admin2'), { accountStatus: 'anonymized' }));
    await assertFails(updateDoc(doc(db, 'users/admin2'), { ...contact, email: 'x@example.com' }));
  });

  test('datos de contacto inválidos se rechazan', async () => {
    await assertFails(updateDoc(doc(as('admin'), 'users/admin2'), { ...contact, fullName: 'A' }));
    await assertFails(
      updateDoc(doc(as('admin'), 'users/admin2'), { ...contact, firstNames: 'X' }),
    );
  });

  test('un cliente no edita a un admin', async () => {
    await assertFails(updateDoc(doc(as('client'), 'users/admin2'), contact));
  });

  test('una cuenta anonimizada no se edita, ni por un admin ni por ella misma', async () => {
    await assertFails(updateDoc(doc(as('admin'), 'users/gone'), contact));
    await assertFails(updateDoc(doc(as('admin'), 'users/gone'), { accountStatus: 'active' }));
    await assertFails(updateDoc(doc(as('gone'), 'users/gone'), { fullName: 'Vuelvo Otra Vez' }));
    await assertFails(
      updateDoc(doc(as('gone'), 'users/gone'), { accountStatus: 'active', role: 'admin' }),
    );
  });

  test('una cuenta anonimizada no se borra ni se anonimiza de nuevo', async () => {
    await assertFails(deleteDoc(doc(as('gone'), 'users/gone')));
    await assertFails(anonymizeBatch(as('admin'), 'admin', 'gone', 1));
  });
});

describe('administradores: anonimizar', () => {
  beforeEach(async () => {
    await seed({
      'users/admin': adminDoc(emails.admin),
      'users/admin2': adminDoc('admin2@example.com'),
      'users/client': { ...clientProfile(), createdAt: Timestamp.now() },
    });
    await seedRegistry(2);
  });

  test('un admin anonimiza a otro bajando 1 el registro', async () => {
    await assertSucceeds(anonymizeBatch(as('admin'), 'admin', 'admin2', 1));
  });

  test('sin bajar el registro, o bajándolo más, se rechaza', async () => {
    const db = as('admin');
    await assertFails(setDoc(doc(db, 'users/admin2'), anonymizedDoc('admin')));
    await assertFails(anonymizeBatch(db, 'admin', 'admin2', 2));
    await assertFails(anonymizeBatch(db, 'admin', 'admin2', 0));
  });

  test('el resultado solo trae los campos permitidos', async () => {
    const db = as('admin');
    const attempts = [
      { email: emails.admin },
      { phoneNumber: '+573009998877' },
      { firstNames: 'Admin' },
      { fullName: 'Admin Prueba' },
      { accountStatus: 'active' },
      { role: 'client' },
      { createdAt: Timestamp.fromDate(new Date('2030-01-01')) },
      { anonymizedBy: 'otro-admin' },
      { anonymizedAt: Timestamp.fromDate(new Date('2020-01-01')) },
    ];
    for (const overrides of attempts) {
      await assertFails(anonymizeBatch(db, 'admin', 'admin2', 1, overrides));
    }
  });

  test('el último admin activo no se puede anonimizar (ni a sí mismo)', async () => {
    await env.clearFirestore();
    await seed({ 'users/admin': adminDoc(emails.admin) });
    await seedRegistry(1);
    await assertFails(anonymizeBatch(as('admin'), 'admin', 'admin', 0));
    await assertFails(deleteDoc(doc(as('admin'), 'users/admin')));
  });

  test('un admin se anonimiza a sí mismo si queda otro activo', async () => {
    await assertSucceeds(anonymizeBatch(as('admin'), 'admin', 'admin', 1));
    // Con el usuario de Auth todavía vivo, ya no puede hacer nada.
    await assertFails(getDoc(doc(as('admin'), registryPath)));
  });

  test('un cliente no anonimiza administradores ni clientes', async () => {
    await assertFails(anonymizeBatch(as('client'), 'client', 'admin2', 1));
    await assertFails(anonymizeBatch(as('admin'), 'admin', 'client', 1));
  });

  test('un admin con contraseña temporal pendiente no anonimiza a nadie', async () => {
    await seed({ 'users/admin': adminDoc(emails.admin, { mustChangePassword: true }) });
    await assertFails(anonymizeBatch(as('admin'), 'admin', 'admin2', 1));
  });

  test('no se deshabilita ni se cambia el rol de un admin (el último incluido)', async () => {
    await assertFails(updateDoc(doc(as('admin'), 'users/admin2'), { accountStatus: 'disabled' }));
    await assertFails(updateDoc(doc(as('admin'), 'users/admin'), { role: 'client' }));
    await assertFails(updateDoc(doc(as('admin'), 'users/admin'), { accountStatus: 'disabled' }));
  });

  test('un admin con contraseña pendiente cuenta en el registro y puede ser anonimizado', async () => {
    await seed({
      'users/admin2': adminDoc('admin2@example.com', { mustChangePassword: true }),
    });
    await assertSucceeds(anonymizeBatch(as('admin'), 'admin', 'admin2', 1));
  });

  test('dos eliminaciones simultáneas con dos activos: solo una se completa', async () => {
    // Cada admin se elimina a sí mismo en una transacción que lee el conteo
    // (lo mismo que hace la app). Ambas leen 2 antes de que cualquiera escriba.
    let arrived = 0;
    let release;
    const bothRead = new Promise((resolve) => (release = resolve));
    const gate = async () => {
      arrived += 1;
      if (arrived === 2) release();
      if (arrived <= 2) await Promise.race([bothRead, new Promise((r) => setTimeout(r, 4000))]);
    };

    const deleteSelf = (uid) => {
      const db = as(uid);
      return runTransaction(db, async (tx) => {
        const registry = await tx.get(doc(db, registryPath));
        const self = await tx.get(doc(db, `users/${uid}`));
        const count = registry.data().activeAdminCount;
        await gate();
        if (count <= 1) throw new Error('lastAdmin');
        tx.set(self.ref, anonymizedDoc(uid));
        tx.update(registry.ref, { activeAdminCount: count - 1 });
      });
    };

    const results = await Promise.allSettled([deleteSelf('admin'), deleteSelf('admin2')]);

    const fulfilled = results.filter((r) => r.status === 'fulfilled');
    const rejected = results.filter((r) => r.status === 'rejected');
    assert.equal(fulfilled.length, 1, JSON.stringify(results.map((r) => r.status)));
    assert.equal(rejected.length, 1);

    await env.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      const registry = await getDoc(doc(db, registryPath));
      assert.equal(registry.data().activeAdminCount, 1);
      const statuses = [
        (await getDoc(doc(db, 'users/admin'))).data().accountStatus,
        (await getDoc(doc(db, 'users/admin2'))).data().accountStatus,
      ].sort();
      assert.deepEqual(statuses, ['active', 'anonymized']);
    });
  });
});

describe('administradores: contraseña temporal pendiente', () => {
  beforeEach(async () => {
    await seed({
      'users/admin': adminDoc(emails.admin),
      'users/pending': adminDoc('pendiente@example.com', { mustChangePassword: true }),
      'users/owner': { ...ownerProfile(), createdAt: Timestamp.now() },
      'users/client': { ...clientProfile(), createdAt: Timestamp.now() },
    });
    await seedRegistry(2);
  });

  test('no tiene permisos de admin activo hasta cambiarla', async () => {
    const db = as('pending');
    await assertFails(
      updateDoc(doc(db, 'users/owner'), {
        accountStatus: 'active',
        approvedBy: 'pending',
        approvedAt: serverTimestamp(),
      }),
    );
    await assertFails(
      updateDoc(doc(db, 'users/admin'), {
        firstNames: 'Otro',
        lastNames: 'Nombre',
        fullName: 'Otro Nombre',
      }),
    );
    await assertFails(updateDoc(doc(db, 'users/client'), { accountStatus: 'disabled' }));
    await assertFails(getDoc(doc(db, registryPath)));
  });

  test('puede leer su propio perfil y limpiar la marca', async () => {
    const db = as('pending');
    await assertSucceeds(getDoc(doc(db, 'users/pending')));
    await assertSucceeds(updateDoc(doc(db, 'users/pending'), { mustChangePassword: false }));
    await assertSucceeds(getDoc(doc(db, registryPath)));
  });

  test('no puede volver a poner la marca, ni limpiarla a otro', async () => {
    await assertFails(updateDoc(doc(as('admin'), 'users/pending'), { mustChangePassword: false }));
    await assertFails(updateDoc(doc(as('client'), 'users/client'), { mustChangePassword: false }));
    await assertFails(
      updateDoc(doc(as('pending'), 'users/pending'), {
        mustChangePassword: false,
        role: 'client',
      }),
    );
    await updateDoc(doc(as('pending'), 'users/pending'), { mustChangePassword: false });
    await assertFails(updateDoc(doc(as('pending'), 'users/pending'), { mustChangePassword: true }));
  });

  test('tras limpiar la marca ya opera como admin activo', async () => {
    await updateDoc(doc(as('pending'), 'users/pending'), { mustChangePassword: false });
    await assertSucceeds(
      updateDoc(doc(as('pending'), 'users/owner'), {
        accountStatus: 'active',
        approvedBy: 'pending',
        approvedAt: serverTimestamp(),
      }),
    );
  });
});

// ---------------------------------------------------------------------------
// CRUD de propietarios: el panel de administración crea la cuenta en `users`
// (password temporal) y edita/borra el documento. Replica lo que escriben
// `OwnerUserDocument.createMap/updateMap` y `deleteOwner` en la app.
// ---------------------------------------------------------------------------

const adminCreatedOwner = (overrides = {}) => ({
  fullName: 'Laura Gómez Restrepo',
  email: 'laura.panel@example.com',
  phoneNumber: '+573001234567',
  phone: '300 123 4567',
  role: 'owner',
  accountStatus: 'active',
  createdAt: serverTimestamp(),
  createdBy: 'admin',
  mustChangePassword: true,
  documentType: 'citizenshipCard',
  documentNumber: '1020304050',
  nit: '1020304050',
  personType: 'natural',
  countryCode: '+57',
  countryName: 'Colombia',
  address: 'Calle 10 # 43-25',
  updatedBy: 'admin',
  updatedAt: serverTimestamp(),
  ...overrides,
});

/// Payload de anonimización que escribe `anonymizeOwner` en la app.
const ownerAnonymization = (overrides = {}) => ({
  fullName: 'Propietario eliminado',
  accountStatus: 'anonymized',
  anonymizedAt: serverTimestamp(),
  anonymizedBy: 'admin',
  updatedBy: 'admin',
  updatedAt: serverTimestamp(),
  phone: null,
  phoneNumber: null,
  phoneCountryCodeId: null,
  nit: null,
  personType: null,
  documentType: null,
  documentNumber: null,
  address: null,
  countryCode: null,
  countryName: null,
  companyName: null,
  planId: null,
  firstNames: null,
  lastNames: null,
  mustChangePassword: null,
  ...overrides,
});

const ownerEdit = () => ({
  fullName: 'Laura Gómez Actualizada',
  phone: '311 999 8888',
  phoneNumber: '+573119998888',
  documentType: 'passport',
  documentNumber: 'AV123456',
  nit: 'AV123456',
  personType: 'natural',
  countryCode: '+57',
  countryName: 'Colombia',
  address: 'Carrera 43 # 10-25',
  updatedBy: 'admin',
  updatedAt: serverTimestamp(),
});

describe('users: CRUD de propietarios por el administrador', () => {
  beforeEach(async () => {
    await seed({
      'users/admin': seededAdmin,
      'users/owner-panel': {
        ...adminCreatedOwner(),
        createdAt: Timestamp.now(),
        updatedAt: Timestamp.now(),
      },
    });
  });

  test('un admin activo crea un propietario con los datos legales', async () => {
    await assertSucceeds(
      setDoc(doc(as('admin'), 'users/owner-new'), adminCreatedOwner()),
    );
  });

  test('también puede crearlo pendiente de aprobación', async () => {
    await assertSucceeds(
      setDoc(
        doc(as('admin'), 'users/owner-pending'),
        adminCreatedOwner({
          email: 'pendiente@example.com',
          accountStatus: 'pending_approval',
        }),
      ),
    );
  });

  test('un cliente no puede crear propietarios', async () => {
    await assertFails(
      setDoc(doc(as('client'), 'users/owner-new'), adminCreatedOwner()),
    );
  });

  test('rechaza un tipo de documento desconocido o un NIT desincronizado', async () => {
    await assertFails(
      setDoc(
        doc(as('admin'), 'users/owner-bad-type'),
        adminCreatedOwner({ documentType: 'otro' }),
      ),
    );
    await assertFails(
      setDoc(
        doc(as('admin'), 'users/owner-bad-nit'),
        adminCreatedOwner({ nit: '900000000-1' }),
      ),
    );
  });

  test('no se puede crear con una cuenta ya activa sin password temporal', async () => {
    await assertFails(
      setDoc(
        doc(as('admin'), 'users/owner-plain'),
        adminCreatedOwner({ mustChangePassword: false }),
      ),
    );
  });

  test('un admin activo edita los datos legales y de contacto', async () => {
    await assertSucceeds(updateDoc(doc(as('admin'), 'users/owner-panel'), ownerEdit()));
  });

  test('un admin no edita el correo, el rol ni el estado del propietario', async () => {
    await assertFails(
      updateDoc(doc(as('admin'), 'users/owner-panel'), {
        ...ownerEdit(),
        email: 'otro@example.com',
      }),
    );
    await assertFails(
      updateDoc(doc(as('admin'), 'users/owner-panel'), {
        ...ownerEdit(),
        role: 'client',
      }),
    );
    await assertFails(
      updateDoc(doc(as('admin'), 'users/owner-panel'), {
        ...ownerEdit(),
        accountStatus: 'disabled',
      }),
    );
  });

  test('un cliente no edita a un propietario', async () => {
    await assertFails(updateDoc(doc(as('client'), 'users/owner-panel'), ownerEdit()));
  });

  test('un admin activo anonimiza a un propietario', async () => {
    await assertSucceeds(
      updateDoc(doc(as('admin'), 'users/owner-panel'), ownerAnonymization()),
    );
  });

  test('exige el nombre placeholder al anonimizar', async () => {
    await assertFails(
      updateDoc(
        doc(as('admin'), 'users/owner-panel'),
        ownerAnonymization({ fullName: 'Laura Gómez' }),
      ),
    );
  });

  test('exige limpiar los datos personales al anonimizar', async () => {
    await assertFails(
      updateDoc(
        doc(as('admin'), 'users/owner-panel'),
        ownerAnonymization({ nit: '1020304050' }),
      ),
    );
  });

  test('un cliente no anonimiza a un propietario', async () => {
    await assertFails(
      updateDoc(doc(as('client'), 'users/owner-panel'), ownerAnonymization()),
    );
  });

  test('un admin no anonimiza a otro administrador', async () => {
    await assertFails(
      updateDoc(doc(as('admin'), 'users/admin'), ownerAnonymization()),
    );
  });

  test('un admin ya no borra al propietario', async () => {
    await assertFails(deleteDoc(doc(as('admin'), 'users/owner-panel')));
  });
});
