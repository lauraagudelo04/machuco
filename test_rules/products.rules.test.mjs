// Reglas de products/{productId}. Solo local (Firebase Emulator Suite).
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
  updateDoc,
} from 'firebase/firestore';

let env;
const as = (uid) => env.authenticatedContext(uid).firestore();
const product = (overrides = {}) => ({
  ownerId: 'owner',
  motelId: 'motel-1',
  name: 'Preservativos',
  description: 'Caja x 3',
  price: 15000.5,
  stock: 12,
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
      ['owner', 'owner', 'active'], ['otherOwner', 'owner', 'active'],
      ['disabledOwner', 'owner', 'disabled'],
      ['client', 'client', 'active'], ['admin', 'admin', 'active'],
    ]) {
      await setDoc(doc(ctx.firestore(), `users/${uid}`), { role, accountStatus });
    }
    await setDoc(doc(ctx.firestore(), 'motels/motel-1'), { ownerId: 'owner' });
    await setDoc(doc(ctx.firestore(), 'motels/motel-2'), { ownerId: 'otherOwner' });
  });
});

describe('products rules', () => {
  test('owner creates, edits and deletes a product of their motel', async () => {
    const ref = doc(as('owner'), 'products/p1');
    await assertSucceeds(setDoc(ref, product()));
    await assertSucceeds(updateDoc(ref, {
      stock: 3, isAvailable: false, updatedAt: serverTimestamp(),
    }));
    await assertSucceeds(deleteDoc(ref));
  });
  test('any signed-in user reads; anonymous cannot', async () => {
    await setDoc(doc(as('owner'), 'products/p1'), product());
    await assertSucceeds(getDoc(doc(as('client'), 'products/p1')));
    await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), 'products/p1')));
  });
  test('owner cannot create a product in a motel they do not own', async () => {
    await assertFails(setDoc(doc(as('owner'), 'products/p1'),
      product({ motelId: 'motel-2' })));
    await assertFails(setDoc(doc(as('owner'), 'products/p1'),
      product({ ownerId: 'otherOwner', motelId: 'motel-2' })));
  });
  test('client and disabled owner cannot write', async () => {
    await assertFails(setDoc(doc(as('client'), 'products/p1'),
      product({ ownerId: 'client' })));
    await assertFails(setDoc(doc(as('disabledOwner'), 'products/p1'),
      product({ ownerId: 'disabledOwner' })));
  });
  test('another owner cannot edit, move or delete it', async () => {
    await setDoc(doc(as('owner'), 'products/p1'), product());
    const other = doc(as('otherOwner'), 'products/p1');
    await assertFails(updateDoc(other, { stock: 1, updatedAt: serverTimestamp() }));
    await assertFails(deleteDoc(other));
    const own = doc(as('owner'), 'products/p1');
    await assertFails(updateDoc(own, { motelId: 'motel-2', updatedAt: serverTimestamp() }));
    await assertFails(updateDoc(own, { ownerId: 'otherOwner', updatedAt: serverTimestamp() }));
  });
  test('admin can manage an existing product', async () => {
    await setDoc(doc(as('owner'), 'products/p1'), product());
    const ref = doc(as('admin'), 'products/p1');
    await assertSucceeds(updateDoc(ref, { isAvailable: false, updatedAt: serverTimestamp() }));
    await assertSucceeds(deleteDoc(ref));
  });
  test('rejects invalid data', async () => {
    const ref = (id) => doc(as('owner'), `products/${id}`);
    await assertFails(setDoc(ref('a'), product({ stock: -1 })));
    await assertFails(setDoc(ref('b'), product({ stock: 1.5 })));
    await assertFails(setDoc(ref('c'), product({ price: -5 })));
    await assertFails(setDoc(ref('d'), product({ name: '' })));
    await assertFails(setDoc(ref('e'), product({ extra: 'x' })));
    await assertFails(setDoc(ref('f'), product({ updatedAt: new Date(0) })));
    await assertSucceeds(setDoc(ref('g'), product({ imageUrl: 'https://x/y.png' })));
  });
});
