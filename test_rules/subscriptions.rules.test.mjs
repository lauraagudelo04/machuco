// Contrato de las reglas para suscripciones y su historial de pagos.
// Solo usa el emulador demo-machuco; nunca el proyecto Firebase compartido.
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
  Timestamp,
  updateDoc,
  writeBatch,
} from 'firebase/firestore';

let env;
const as = (uid) => env.authenticatedContext(uid).firestore();
const anonymous = () => env.unauthenticatedContext().firestore();

const subscription = (overrides = {}) => ({
  ownerId: 'owner',
  localId: 1,
  userEmail: 'owner@example.com',
  planId: 2,
  planName: 'Premium',
  motelName: 'Motel Machuco',
  amount: 150000,
  billingPeriod: 'Mensual',
  nextBillingDate: Timestamp.fromDate(new Date('2030-12-01T00:00:00Z')),
  status: 'active',
  features: ['Gestión de habitaciones', 'Reportes'],
  updatedAt: serverTimestamp(),
  ...overrides,
});

const payment = (overrides = {}) => ({
  ownerId: 'owner',
  localId: 1,
  subscriptionLocalId: 1,
  date: Timestamp.fromDate(new Date('2030-11-01T00:00:00Z')),
  amount: 150000,
  paymentMethod: 'Transferencia bancaria',
  reference: 'SUB-2026-0001',
  status: 'completed',
  updatedAt: serverTimestamp(),
  ...overrides,
});

const subscriptionRef = (db) =>
  doc(db, 'subscriptions/owner');
const paymentRef = (db, id = '1') =>
  doc(db, `subscriptionPayments/owner_${id}`);

async function seedSubscriptionAndPayment() {
  const db = as('owner');
  const batch = writeBatch(db);
  batch.set(subscriptionRef(db), subscription());
  batch.set(paymentRef(db), payment());
  await batch.commit();
}

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
    const db = ctx.firestore();
    for (const [uid, role, accountStatus] of [
      ['owner', 'owner', 'active'],
      ['otherOwner', 'owner', 'active'],
      ['disabledOwner', 'owner', 'disabled'],
      ['client', 'client', 'active'],
      ['admin', 'admin', 'active'],
    ]) {
      await setDoc(doc(db, `users/${uid}`), { role, accountStatus });
    }
  });
});

describe('suscripciones y pagos de suscripción', () => {
  test('un propietario activo guarda la suscripción y su pago en un batch', async () => {
    await assertSucceeds(seedSubscriptionAndPayment());

    await assertSucceeds(getDoc(subscriptionRef(as('owner'))));
    await assertSucceeds(getDoc(paymentRef(as('owner'))));
  });

  test('el propietario puede actualizar datos válidos sin cambiar el ID local', async () => {
    await seedSubscriptionAndPayment();

    await assertSucceeds(updateDoc(subscriptionRef(as('owner')), {
      amount: 230000,
      updatedAt: serverTimestamp(),
    }));
    await assertSucceeds(updateDoc(paymentRef(as('owner')), {
      reference: 'SUB-2026-0002',
      updatedAt: serverTimestamp(),
    }));
  });

  test('admin activo puede leer, pero no crear ni editar la suscripción', async () => {
    await seedSubscriptionAndPayment();

    await assertSucceeds(getDoc(subscriptionRef(as('admin'))));
    await assertSucceeds(getDoc(paymentRef(as('admin'))));
    await assertFails(setDoc(doc(as('admin'), 'users/admin/subscriptions/1'), subscription()));
    await assertFails(updateDoc(subscriptionRef(as('admin')), {
      amount: 1,
      updatedAt: serverTimestamp(),
    }));
  });

  test('solo el propietario autenticado puede leer su subcolección', async () => {
    await seedSubscriptionAndPayment();

    await assertFails(getDoc(subscriptionRef(as('otherOwner'))));
    await assertFails(getDoc(paymentRef(as('otherOwner'))));
    await assertFails(getDoc(subscriptionRef(as('client'))));
    await assertFails(getDoc(subscriptionRef(anonymous())));
  });

  test('un cliente o propietario deshabilitado no puede guardar datos', async () => {
    await assertFails(setDoc(
      doc(as('client'), 'users/client/subscriptions/1'),
      subscription({ userEmail: 'client@example.com' }),
    ));
    await assertFails(setDoc(
      doc(as('disabledOwner'), 'users/disabledOwner/subscriptions/1'),
      subscription({ userEmail: 'disabled@example.com' }),
    ));
  });

  test('rechaza campos, tipos y fechas inválidos', async () => {
    for (const overrides of [
      { amount: 0 },
      { planId: '2' },
      { nextBillingDate: '2030-12-01' },
      { status: 'paid' },
      { extraField: true },
    ]) {
      await assertFails(setDoc(
        doc(as('owner'), 'users/owner/subscriptions/1'),
        subscription(overrides),
      ));
    }
  });

  test('rechaza un pago sin suscripción padre o con vínculo inconsistente', async () => {
    await assertFails(setDoc(
      paymentRef(as('owner')),
      payment(),
    ));

    await assertSucceeds(setDoc(subscriptionRef(as('owner')), subscription()));
    await assertFails(setDoc(
      paymentRef(as('owner')),
      payment({ subscriptionLocalId: 99 }),
    ));
  });

  test('no se pueden borrar suscripciones ni pagos ni cambiar sus identificadores', async () => {
    await seedSubscriptionAndPayment();

    await assertFails(deleteDoc(subscriptionRef(as('owner'))));
    await assertFails(deleteDoc(paymentRef(as('owner'))));
    await assertFails(updateDoc(subscriptionRef(as('owner')), {
      localId: 99,
      updatedAt: serverTimestamp(),
    }));
    await assertFails(updateDoc(paymentRef(as('owner')), {
      localId: 99,
      updatedAt: serverTimestamp(),
    }));
  });
});
