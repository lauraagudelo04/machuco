// Pruebas de firestore.rules (pqrs, traces y photos) contra el emulador de
// Firestore. Cubren la matriz rol por accion de la Etapa 3 del modulo PQRS.
// Ejecutar con `npm run test:emulator` (proyecto ficticio demo-machuco).
import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, test } from 'node:test';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  Bytes,
  collection,
  deleteDoc,
  deleteField,
  doc,
  getDoc,
  getDocs,
  orderBy,
  query,
  serverTimestamp,
  setDoc,
  Timestamp,
  updateDoc,
  where,
  writeBatch,
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
  pendingClient: user('client', 'pending'),
  owner: user('owner'),
  otherOwner: user('owner'),
  admin: user('admin'),
};

const as = (uid) =>
  env
    .authenticatedContext(uid, { email: users[uid]?.email, email_verified: true })
    .firestore();

const TIMEOUT_MESSAGE = 'Cerrada por vencimiento del plazo de confirmación';
const DAY = 24 * 60 * 60 * 1000;
const daysAgo = (days) => Timestamp.fromMillis(Date.now() - days * DAY);
const bytesOf = (size) => Bytes.fromUint8Array(new Uint8Array(size).fill(1));

/// Documento pqrs/{id} valido para crear (hasValidPqrsCreate).
const pqrsData = (overrides = {}) => ({
  clientId: 'client',
  clientName: 'Cliente Uno',
  motelId: 'motel-1',
  motelName: 'Motel Uno',
  ownerId: 'owner',
  type: 'queja',
  subject: 'Ruido excesivo',
  description: 'Hubo ruido excesivo en la habitacion vecina.',
  status: 'pending',
  photoCount: 0,
  createdAt: serverTimestamp(),
  updatedAt: serverTimestamp(),
  ...overrides,
});

const traceData = (role, uid, overrides = {}) => ({
  authorId: uid,
  authorRole: role,
  authorName: `Autor ${role}`,
  message: 'Mensaje de la entrada',
  photoCount: 0,
  createdAt: serverTimestamp(),
  ...overrides,
});

const photoData = (uid, role, traceId, overrides = {}) => ({
  bytes: bytesOf(100),
  mimeType: 'image/jpeg',
  traceId,
  authorId: uid,
  authorRole: role,
  createdAt: serverTimestamp(),
  ...overrides,
});

/// Siembra una PQRS ya guardada (sin reglas) en el estado indicado.
const seed = async (id, fields = {}, { withPhotos = false } = {}) => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, `pqrs/${id}`), {
      ...pqrsData(),
      createdAt: daysAgo(10),
      updatedAt: daysAgo(10),
      ...fields,
    });
    await setDoc(
      doc(db, `pqrs/${id}/traces/${id}-open`),
      traceData('client', 'client', { createdAt: daysAgo(10) }),
    );
    if (withPhotos) {
      await setDoc(
        doc(db, `pqrs/${id}/photos/${id}-open_1`),
        photoData('client', 'client', `${id}-open`, { createdAt: daysAgo(10) }),
      );
    }
  });
};

/// Lote de una accion: traza + cambio de la PQRS (opcional) + fotos.
const advance = async (uid, role, id, { change, update, trace, photos = [] } = {}) => {
  const db = as(uid);
  const traceId = `trace-${Math.random().toString(36).slice(2)}`;
  const batch = writeBatch(db);
  batch.set(
    doc(db, `pqrs/${id}/traces/${traceId}`),
    traceData(role, uid, {
      photoCount: photos.length,
      ...(change ? { statusChange: change } : {}),
      ...trace,
    }),
  );
  photos.forEach((photo, index) => {
    batch.set(doc(db, `pqrs/${id}/photos/${traceId}_${index + 1}`), photo(traceId));
  });
  if (update) {
    batch.update(doc(db, `pqrs/${id}`), { updatedAt: serverTimestamp(), ...update });
  }
  return batch.commit();
};

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-machuco',
    firestore: {
      rules: readFileSync(
        process.env.FIRESTORE_RULES_PATH ?? new URL('../firestore.rules', import.meta.url),
        'utf8',
      ),
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
    await setDoc(doc(db, 'motels/motel-1'), { ownerId: 'owner', isAvailable: true });
  });
});

/// Radicacion: pqrs + entrada de apertura + fotos en un solo lote.
const open = (uid, { pqrs = {}, trace = {}, photos = [], skipTrace = false } = {}) => {
  const db = as(uid);
  const id = 'pqrs-new';
  const batch = writeBatch(db);
  batch.set(
    doc(db, `pqrs/${id}`),
    pqrsData({ photoCount: photos.length, ...pqrs }),
  );
  if (!skipTrace) {
    batch.set(
      doc(db, `pqrs/${id}/traces/${id}-open`),
      traceData('client', uid, { photoCount: photos.length, ...trace }),
    );
  }
  photos.forEach((photo, index) => {
    batch.set(doc(db, `pqrs/${id}/photos/${id}-open_${index + 1}`), photo(`${id}-open`));
  });
  return batch.commit();
};

const okPhoto = (extra = {}) => (traceId) => photoData('client', 'client', traceId, extra);

describe('crear PQRS', () => {
  test('[PQ-01] el cliente radica con 2 fotos validas en un lote', async () => {
    await assertSucceeds(open('client', { photos: [okPhoto(), okPhoto({ mimeType: 'image/png' })] }));
  });

  test('[PQ-02] sin entrada de apertura se rechaza', async () => {
    await assertFails(open('client', { skipTrace: true }));
  });

  test('[PQ-03] no radica a nombre de otro cliente', async () => {
    await assertFails(open('client', { pqrs: { clientId: 'otherClient' } }));
  });

  test('[PQ-04] ownerId distinto al del motel se rechaza', async () => {
    await assertFails(open('client', { pqrs: { ownerId: 'otherOwner' } }));
  });

  test('[PQ-05] propietario, admin y cliente no activo no radican', async () => {
    await assertFails(open('owner', { pqrs: { clientId: 'owner' }, trace: {} }));
    await assertFails(open('admin', { pqrs: { clientId: 'admin' }, trace: {} }));
    await assertFails(open('pendingClient', { pqrs: { clientId: 'pendingClient' } }));
  });

  test('[PQ-06] asunto, descripcion y tipo fuera de limite se rechazan', async () => {
    await assertFails(open('client', { pqrs: { subject: 'ab' } }));
    await assertFails(open('client', { pqrs: { subject: 'x'.repeat(101) } }));
    await assertFails(open('client', { pqrs: { description: 'corta' } }));
    await assertFails(open('client', { pqrs: { description: 'x'.repeat(1001) } }));
    await assertFails(open('client', { pqrs: { type: 'denuncia' } }));
  });

  test('[PQ-07] estado distinto de pending, resolvedAt o closedBy se rechazan', async () => {
    await assertFails(open('client', { pqrs: { status: 'resolved' } }));
    await assertFails(open('client', { pqrs: { resolvedAt: serverTimestamp() } }));
    await assertFails(open('client', { pqrs: { closedBy: 'client' } }));
  });

  test('[PQ-08] motel inexistente se rechaza', async () => {
    await assertFails(open('client', { pqrs: { motelId: 'no-existe' } }));
  });

  test('[PQ-09] foto de 900 KiB pasa; mayor, tipo no permitido o cuarta foto no', async () => {
    await assertSucceeds(open('client', { photos: [okPhoto({ bytes: bytesOf(921600) })] }));
    await assertFails(open('client', { photos: [okPhoto({ bytes: bytesOf(921601) })] }));
    await assertFails(open('client', { photos: [okPhoto({ mimeType: 'image/gif' })] }));
    await assertFails(
      open('client', { photos: [okPhoto(), okPhoto(), okPhoto(), okPhoto()], trace: { photoCount: 3 } }),
    );
  });

  test('[PQ-10] foto con id fuera de _1 a _3 o sobre photoCount se rechaza', async () => {
    const db = as('client');
    const batch = writeBatch(db);
    batch.set(doc(db, 'pqrs/pqrs-new'), pqrsData());
    batch.set(doc(db, 'pqrs/pqrs-new/traces/pqrs-new-open'), traceData('client', 'client'));
    batch.set(doc(db, 'pqrs/pqrs-new/photos/pqrs-new-open_1'), photoData('client', 'client', 'pqrs-new-open'));
    await assertFails(batch.commit());
  });
});

describe('propietario', () => {
  test('[PQ-11] pending a in_progress con traza', async () => {
    await seed('p1');
    await assertSucceeds(advance('owner', 'owner', 'p1', { change: 'in_progress', update: { status: 'in_progress' } }));
  });

  test('[PQ-12] comenta sobre in_progress sin cambiar estado', async () => {
    await seed('p1', { status: 'in_progress' });
    await assertSucceeds(advance('owner', 'owner', 'p1'));
  });

  test('[PQ-13] resuelve con resolvedAt de servidor; con otra fecha no', async () => {
    await seed('p1', { status: 'in_progress' });
    await assertSucceeds(
      advance('owner', 'owner', 'p1', { change: 'resolved', update: { status: 'resolved', resolvedAt: serverTimestamp() } }),
    );
    await seed('p2', { status: 'in_progress' });
    await assertFails(
      advance('owner', 'owner', 'p2', { change: 'resolved', update: { status: 'resolved', resolvedAt: daysAgo(9) } }),
    );
    await seed('p3', { status: 'in_progress' });
    await assertFails(advance('owner', 'owner', 'p3', { change: 'resolved', update: { status: 'resolved' } }));
  });

  test('[PQ-14] rechaza una PQRS abierta', async () => {
    await seed('p1');
    await assertSucceeds(advance('owner', 'owner', 'p1', { change: 'rejected', update: { status: 'rejected' } }));
  });

  test('[PQ-15] no comenta ni rechaza sobre resolved', async () => {
    await seed('p1', { status: 'resolved', resolvedAt: daysAgo(1) });
    await assertFails(advance('owner', 'owner', 'p1'));
    await assertFails(advance('owner', 'owner', 'p1', { change: 'rejected', update: { status: 'rejected' } }));
  });

  test('[PQ-16] cierre por vencimiento: solo pasados 7 dias, con closedBy owner_timeout', async () => {
    await seed('p1', { status: 'resolved', resolvedAt: daysAgo(8) });
    await assertSucceeds(
      advance('owner', 'owner', 'p1', {
        change: 'closed',
        update: { status: 'closed', closedBy: 'owner_timeout' },
        trace: { message: TIMEOUT_MESSAGE },
      }),
    );
    await seed('p2', { status: 'resolved', resolvedAt: daysAgo(6) });
    await assertFails(
      advance('owner', 'owner', 'p2', {
        change: 'closed',
        update: { status: 'closed', closedBy: 'owner_timeout' },
        trace: { message: TIMEOUT_MESSAGE },
      }),
    );
    await seed('p3', { status: 'resolved', resolvedAt: daysAgo(8) });
    await assertFails(
      advance('owner', 'owner', 'p3', {
        change: 'closed',
        update: { status: 'closed', closedBy: 'client' },
        trace: { message: TIMEOUT_MESSAGE },
      }),
    );
    await seed('p4', { status: 'resolved', resolvedAt: daysAgo(8) });
    await assertFails(
      advance('owner', 'owner', 'p4', {
        change: 'closed',
        update: { status: 'closed', closedBy: 'owner_timeout' },
        trace: { message: 'Otro mensaje' },
      }),
    );
  });

  test('[PQ-17] otro propietario no actua', async () => {
    await seed('p1');
    await assertFails(advance('otherOwner', 'owner', 'p1', { change: 'in_progress', update: { status: 'in_progress' } }));
  });
});

describe('cliente', () => {
  test('[PQ-18] comenta sobre pending e in_progress sin cambiar estado', async () => {
    await seed('p1');
    await seed('p2', { status: 'in_progress' });
    await assertSucceeds(advance('client', 'client', 'p1', { photos: [okPhoto()] }));
    await assertSucceeds(advance('client', 'client', 'p2'));
  });

  test('[PQ-19] confirma resolved y cierra con closedBy client', async () => {
    await seed('p1', { status: 'resolved', resolvedAt: daysAgo(1) });
    await assertSucceeds(
      advance('client', 'client', 'p1', { change: 'closed', update: { status: 'closed', closedBy: 'client' } }),
    );
    await seed('p2', { status: 'resolved', resolvedAt: daysAgo(1) });
    await assertFails(
      advance('client', 'client', 'p2', { change: 'closed', update: { status: 'closed', closedBy: 'owner_timeout' } }),
    );
    await seed('p3', { status: 'resolved', resolvedAt: daysAgo(1) });
    await assertFails(advance('client', 'client', 'p3', { change: 'closed', update: { status: 'closed' } }));
  });

  test('[PQ-20] reabre resolved eliminando resolvedAt; conservarlo no', async () => {
    await seed('p1', { status: 'resolved', resolvedAt: daysAgo(1) });
    await assertSucceeds(
      advance('client', 'client', 'p1', { change: 'in_progress', update: { status: 'in_progress', resolvedAt: deleteField() } }),
    );
    await seed('p2', { status: 'resolved', resolvedAt: daysAgo(1) });
    await assertFails(
      advance('client', 'client', 'p2', { change: 'in_progress', update: { status: 'in_progress' } }),
    );
  });

  test('[PQ-21] no resuelve, no rechaza y no cierra sin resolved', async () => {
    await seed('p1');
    await assertFails(advance('client', 'client', 'p1', { change: 'resolved', update: { status: 'resolved', resolvedAt: serverTimestamp() } }));
    await assertFails(advance('client', 'client', 'p1', { change: 'rejected', update: { status: 'rejected' } }));
    await assertFails(advance('client', 'client', 'p1', { change: 'closed', update: { status: 'closed', closedBy: 'client' } }));
  });

  test('[PQ-22] otro cliente no comenta', async () => {
    await seed('p1');
    await assertFails(advance('otherClient', 'client', 'p1'));
  });
});

describe('estados finales, trazas y fotos', () => {
  test('[PQ-23] closed y rejected no admiten trazas ni cambios', async () => {
    await seed('p1', { status: 'closed', closedBy: 'client', resolvedAt: daysAgo(2) });
    await seed('p2', { status: 'rejected' });
    for (const id of ['p1', 'p2']) {
      await assertFails(advance('client', 'client', id));
      await assertFails(advance('owner', 'owner', id));
      await assertFails(advance('owner', 'owner', id, { change: 'in_progress', update: { status: 'in_progress' } }));
    }
  });

  test('[PQ-24] autor y rol de la traza deben coincidir con quien escribe', async () => {
    await seed('p1');
    await assertFails(advance('client', 'client', 'p1', { trace: { authorId: 'owner' } }));
    await assertFails(advance('client', 'owner', 'p1'));
    await assertFails(advance('owner', 'client', 'p1'));
  });

  test('[PQ-25] statusChange debe coincidir con el estado que deja el lote', async () => {
    await seed('p1');
    await assertFails(advance('owner', 'owner', 'p1', { change: 'in_progress' }));
    await assertFails(advance('owner', 'owner', 'p1', { change: 'resolved', update: { status: 'in_progress' } }));
    await assertFails(advance('owner', 'owner', 'p1', { update: { status: 'in_progress' } }));
  });

  test('[PQ-26] no se edita ni borra la PQRS, las trazas ni las fotos', async () => {
    await seed('p1', {}, { withPhotos: true });
    for (const uid of ['client', 'owner', 'admin']) {
      await assertFails(deleteDoc(doc(as(uid), 'pqrs/p1')));
      await assertFails(deleteDoc(doc(as(uid), 'pqrs/p1/traces/p1-open')));
      await assertFails(updateDoc(doc(as(uid), 'pqrs/p1/traces/p1-open'), { message: 'x' }));
      await assertFails(deleteDoc(doc(as(uid), 'pqrs/p1/photos/p1-open_1')));
      await assertFails(updateDoc(doc(as(uid), 'pqrs/p1/photos/p1-open_1'), { mimeType: 'image/png' }));
    }
  });

  test('[PQ-27] el update solo toca status, updatedAt, resolvedAt y closedBy', async () => {
    await seed('p1');
    await assertFails(updateDoc(doc(as('owner'), 'pqrs/p1'), { subject: 'Cambiado', updatedAt: serverTimestamp() }));
    await assertFails(updateDoc(doc(as('owner'), 'pqrs/p1'), { ownerId: 'otherOwner', updatedAt: serverTimestamp() }));
  });

  test('[PQ-28] el administrador no escribe', async () => {
    await seed('p1');
    await assertFails(updateDoc(doc(as('admin'), 'pqrs/p1'), { status: 'in_progress', updatedAt: serverTimestamp() }));
    await assertFails(advance('admin', 'owner', 'p1'));
  });
});

describe('leer', () => {
  test('[PQ-29] cliente dueno, propietario y admin leen PQRS, trazas y fotos', async () => {
    await seed('p1', {}, { withPhotos: true });
    for (const uid of ['client', 'owner', 'admin']) {
      await assertSucceeds(getDoc(doc(as(uid), 'pqrs/p1')));
      await assertSucceeds(getDoc(doc(as(uid), 'pqrs/p1/traces/p1-open')));
      await assertSucceeds(getDocs(collection(as(uid), 'pqrs/p1/photos')));
    }
  });

  test('[PQ-30] otro cliente, otro propietario y anonimo no leen', async () => {
    await seed('p1', {}, { withPhotos: true });
    for (const uid of ['otherClient', 'otherOwner']) {
      await assertFails(getDoc(doc(as(uid), 'pqrs/p1')));
      await assertFails(getDoc(doc(as(uid), 'pqrs/p1/traces/p1-open')));
      await assertFails(getDocs(collection(as(uid), 'pqrs/p1/photos')));
    }
    await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), 'pqrs/p1')));
  });

  test('[PQ-31] consultas por clientId y ownerId ordenadas por createdAt; sin filtro solo admin', async () => {
    await seed('p1');
    await assertSucceeds(
      getDocs(query(collection(as('client'), 'pqrs'), where('clientId', '==', 'client'), orderBy('createdAt', 'desc'))),
    );
    await assertSucceeds(
      getDocs(query(collection(as('owner'), 'pqrs'), where('ownerId', '==', 'owner'), orderBy('createdAt', 'desc'))),
    );
    await assertSucceeds(getDocs(query(collection(as('admin'), 'pqrs'), orderBy('createdAt', 'desc'))));
    await assertFails(getDocs(collection(as('client'), 'pqrs')));
    await assertFails(
      getDocs(query(collection(as('client'), 'pqrs'), where('clientId', '==', 'otherClient'))),
    );
  });
});
