// Reglas de la copia de moteles en Firestore (motels/{motelId}, rama
// feature_marco). Las reglas de habitaciones confían en ownerId, así que nadie
// debe poder apropiarse de un motel ajeno. Solo local (emulador).
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
} from 'firebase/firestore';

let env;
const as = (uid) => env.authenticatedContext(uid).firestore();
const motel = (overrides = {}) => ({
  ownerId: 'owner',
  name: 'Motel Luna Azul',
  isAvailable: true,
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
after(async () => { await env?.cleanup(); });
beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    for (const [uid, role, accountStatus] of [
      ['owner', 'owner', 'active'],
      ['otherOwner', 'owner', 'active'],
      ['pendingOwner', 'owner', 'pending'],
      ['client', 'client', 'active'],
      ['admin', 'admin', 'active'],
    ]) {
      await setDoc(doc(ctx.firestore(), `users/${uid}`), { role, accountStatus });
    }
  });
});

describe('motels: copia de SQL Connect', () => {
  test('el propietario activo crea y edita su motel; cualquiera con sesión lo lee', async () => {
    const ref = doc(as('owner'), 'motels/m1');
    await assertSucceeds(setDoc(ref, motel()));
    await assertSucceeds(setDoc(ref, motel({ name: 'Motel Luna', isAvailable: false })));
    await assertSucceeds(getDoc(doc(as('client'), 'motels/m1')));
  });

  test('el propietario no crea moteles a nombre de otro', async () => {
    await assertFails(setDoc(doc(as('owner'), 'motels/m1'), motel({ ownerId: 'otherOwner' })));
  });

  test('otro propietario no puede apropiarse ni editar un motel ajeno', async () => {
    await setDoc(doc(as('owner'), 'motels/m1'), motel());
    const other = doc(as('otherOwner'), 'motels/m1');
    await assertFails(setDoc(other, motel({ ownerId: 'otherOwner' })));
    await assertFails(setDoc(other, motel({ name: 'Cambiado' })));
  });

  test('el propietario no puede cederle su motel a otro', async () => {
    const ref = doc(as('owner'), 'motels/m1');
    await setDoc(ref, motel());
    await assertFails(setDoc(ref, motel({ ownerId: 'otherOwner' })));
  });

  test('el administrador crea y reasigna moteles de cualquier propietario', async () => {
    const ref = doc(as('admin'), 'motels/m1');
    await assertSucceeds(setDoc(ref, motel()));
    await assertSucceeds(setDoc(ref, motel({ ownerId: 'otherOwner' })));
  });

  test('propietario pendiente, cliente y sin sesión no escriben', async () => {
    await assertFails(setDoc(doc(as('pendingOwner'), 'motels/m1'), motel({ ownerId: 'pendingOwner' })));
    await assertFails(setDoc(doc(as('client'), 'motels/m1'), motel({ ownerId: 'client' })));
    await assertFails(setDoc(doc(env.unauthenticatedContext().firestore(), 'motels/m1'), motel()));
    await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), 'motels/m1')));
  });

  test('nadie borra moteles, ni el administrador', async () => {
    await setDoc(doc(as('owner'), 'motels/m1'), motel());
    await assertFails(deleteDoc(doc(as('owner'), 'motels/m1')));
    await assertFails(deleteDoc(doc(as('admin'), 'motels/m1')));
  });
});

// Habitaciones: ownsRoomMotel acepta la copia motels/{motelId}.
const roomType = (overrides = {}) => ({
  id: 't1',
  motelId: 'm1',
  ownerId: 'owner',
  name: 'Suite',
  deleted: false,
  updatedAt: serverTimestamp(),
  ...overrides,
});
const room = (overrides = {}) => ({
  id: 'r1',
  motelId: 'm1',
  ownerId: 'owner',
  name: 'Habitación 101',
  description: 'Con jacuzzi',
  idType: 't1',
  pricePerHour: 50000,
  roomNumber: '101',
  capacity: 2,
  imageUrls: [],
  isActive: true,
  includedServices: [],
  deleted: false,
  updatedAt: serverTimestamp(),
  ...overrides,
});

describe('habitaciones con el motel registrado en motels', () => {
  test('el dueño del motel crea tipos de habitación y habitaciones', async () => {
    await setDoc(doc(as('owner'), 'motels/m1'), motel());
    await assertSucceeds(setDoc(doc(as('owner'), 'room_types/t1'), roomType()));
    await assertSucceeds(setDoc(doc(as('owner'), 'rooms/r1'), room()));
  });

  test('otro propietario no crea tipos ni habitaciones en un motel ajeno', async () => {
    await setDoc(doc(as('owner'), 'motels/m1'), motel());
    await assertFails(setDoc(
      doc(as('otherOwner'), 'room_types/t1'),
      roomType({ ownerId: 'otherOwner' }),
    ));
  });

  test('sin registro en motels ni en room_motels no se crean tipos', async () => {
    await assertFails(setDoc(doc(as('owner'), 'room_types/t1'), roomType()));
  });

  test('room_motels sin copia en motels no autoriza habitaciones', async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'room_motels/m2'), { ownerId: 'owner' });
    });
    await assertFails(setDoc(
      doc(as('owner'), 'room_types/t2'),
      roomType({ id: 't2', motelId: 'm2' }),
    ));
  });
});
