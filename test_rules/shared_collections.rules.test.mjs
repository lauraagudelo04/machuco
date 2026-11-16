// Regression tests for rules already published by other branches. Local only.
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
const service = (overrides = {}) => ({
  ownerId: 'owner',
  motelId: 'motel-1',
  name: 'Decoración',
  description: 'Decoración de la habitación',
  category: 'Servicios',
  price: 50000,
  active: true,
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
    for (const [uid, role] of [
      ['owner', 'owner'], ['otherOwner', 'owner'],
      ['client', 'client'], ['admin', 'admin'],
    ]) {
      await setDoc(doc(ctx.firestore(), `users/${uid}`), {
        role, accountStatus: 'active',
      });
    }
  });
});

describe('published additionalServices rules are preserved', () => {
  test('owner creates, edits and deletes their service; client can read', async () => {
    const ref = doc(as('owner'), 'additionalServices/service-1');
    await assertSucceeds(setDoc(ref, service()));
    await assertSucceeds(getDoc(doc(as('client'), 'additionalServices/service-1')));
    await assertSucceeds(updateDoc(ref, {
      price: 60000, updatedAt: serverTimestamp(),
    }));
    await assertSucceeds(deleteDoc(ref));
  });
  test('another owner cannot edit, transfer or delete the service', async () => {
    await setDoc(doc(as('owner'), 'additionalServices/service-1'), service());
    const other = doc(as('otherOwner'), 'additionalServices/service-1');
    await assertFails(updateDoc(other, { price: 1, updatedAt: serverTimestamp() }));
    await assertFails(updateDoc(other, { ownerId: 'otherOwner', updatedAt: serverTimestamp() }));
    await assertFails(deleteDoc(other));
  });
  test('client writes and anonymous reads remain forbidden', async () => {
    await assertFails(setDoc(doc(as('client'), 'additionalServices/service-1'),
      service({ ownerId: 'client' })));
    await setDoc(doc(as('owner'), 'additionalServices/service-1'), service());
    await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(),
      'additionalServices/service-1')));
  });
  test('admin can manage an existing service without changing its owner', async () => {
    await setDoc(doc(as('owner'), 'additionalServices/service-1'), service());
    const ref = doc(as('admin'), 'additionalServices/service-1');
    await assertSucceeds(updateDoc(ref, { active: false, updatedAt: serverTimestamp() }));
    await assertSucceeds(deleteDoc(ref));
  });
});

describe('published motels mirror rules are preserved', () => {
  test('owner writes their mirror, signed-in client reads, nobody deletes', async () => {
    const ref = doc(as('owner'), 'motels/motel-1');
    await assertSucceeds(setDoc(ref, { ownerId: 'owner', name: 'Motel Uno' }));
    await assertSucceeds(getDoc(doc(as('client'), 'motels/motel-1')));
    await assertFails(deleteDoc(ref));
    await assertFails(deleteDoc(doc(as('admin'), 'motels/motel-1')));
  });
  test('client cannot write the mirror or read anonymously', async () => {
    await assertFails(setDoc(doc(as('client'), 'motels/motel-1'), { ownerId: 'client' }));
    await setDoc(doc(as('owner'), 'motels/motel-1'), { ownerId: 'owner' });
    await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), 'motels/motel-1')));
  });
});
