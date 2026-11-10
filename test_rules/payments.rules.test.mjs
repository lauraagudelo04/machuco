// Only demo-machuco + Firestore Emulator. Never the shared Firebase project.
import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, test } from 'node:test';
import { assertFails, assertSucceeds, initializeTestEnvironment } from '@firebase/rules-unit-testing';
import { collection, doc, getDoc, getDocs, serverTimestamp, setDoc, Timestamp, updateDoc, writeBatch } from 'firebase/firestore';

let env;
const as = (uid) => env.authenticatedContext(uid).firestore();
const checkIn = Timestamp.fromDate(new Date('2030-11-10T20:00:00Z'));
const reservation = (overrides = {}) => ({
  ownerId: 'owner', guestId: 'client', guestName: 'Cliente Uno',
  requestId: 'request-1', motelId: 'motel-1', motelName: 'Motel Uno',
  roomId: 'room-1', roomName: 'Suite', roomNumber: '101', checkIn,
  checkOut: Timestamp.fromDate(new Date('2030-11-10T23:00:00Z')),
  stayMode: 'dateTimeRange', guestCount: 2, services: [], products: [],
  roomTotal: 120000, total: 120000, status: 'pending',
  createdAt: Timestamp.now(), invoiceAccessStatus: 'notApplicable',
  updatedAt: Timestamp.now(), ...overrides,
});
const payment = (overrides = {}) => ({
  ownerId: 'owner', bookingId: 'reservation-1', bookingReference: 'request-1',
  clientId: 'client', client: 'Cliente Uno', motelId: 'motel-1', motel: 'Motel Uno',
  roomId: 'room-1', room: 'Suite', reservationDate: checkIn,
  amount: 120000, status: 'pending', updatedAt: serverTimestamp(), ...overrides,
});
async function selectLocal(uid = 'client', overrides = {}, id = 'pay-reservation-1') {
  const db = as(uid);
  const batch = writeBatch(db);
  batch.set(doc(db, `payments/${id}`), payment(overrides));
  batch.update(doc(db, 'reservations/reservation-1'), {
    paymentMethod: 'En el Local', updatedAt: serverTimestamp(),
  });
  return batch.commit();
}
async function receive(uid = 'owner') {
  const db = as(uid);
  const batch = writeBatch(db);
  batch.update(doc(db, 'payments/pay-reservation-1'), {
    status: 'paid', paymentMethodId: 1, paymentMethodName: 'Efectivo',
    paidAt: serverTimestamp(), receiptNumber: 'LOCAL-pay-reservation-1',
    updatedAt: serverTimestamp(),
  });
  batch.update(doc(db, 'reservations/reservation-1'), {
    status: 'upcoming', paymentMethod: 'Efectivo', invoiceAccessStatus: 'pending',
    updatedAt: serverTimestamp(),
  });
  return batch.commit();
}
before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-machuco',
    firestore: { rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8') },
  });
});
after(async () => { await env?.cleanup(); });
beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    for (const [uid, role, accountStatus] of [
      ['client', 'client', 'active'], ['otherClient', 'client', 'active'],
      ['owner', 'owner', 'active'], ['otherOwner', 'owner', 'active'],
      ['disabledClient', 'client', 'disabled'], ['admin', 'admin', 'active'],
    ]) await setDoc(doc(db, `users/${uid}`), { role, accountStatus });
    await setDoc(doc(db, 'reservations/reservation-1'), reservation());
  });
});

describe('En el Local: reservation and payment contract', () => {
  test('client creates one pending payment and keeps the reservation unpaid', async () => {
    await assertSucceeds(selectLocal());
    const booking = await getDoc(doc(as('client'), 'reservations/reservation-1'));
    const stored = await getDoc(doc(as('owner'), 'payments/pay-reservation-1'));
    if (booking.data().status !== 'pending' || stored.data().status !== 'pending') throw Error('Not pending');
  });
  test('an identical retry is allowed but does not grant a client read access', async () => {
    await assertSucceeds(selectLocal());
    await assertSucceeds(selectLocal());
    await assertFails(getDoc(doc(as('client'), 'payments/pay-reservation-1')));
    await assertFails(getDocs(collection(as('client'), 'payments')));
  });
  for (const overrides of [
    { amount: 1 }, { motelId: 'other-motel' }, { ownerId: 'otherOwner' },
    { roomId: 'other-room' }, { clientId: 'otherClient' },
    { bookingId: 'missing' }, { reservationDate: Timestamp.fromMillis(0) },
  ]) test(`rejects mismatched data: ${JSON.stringify(overrides)}`, async () => {
    await assertFails(selectLocal('client', overrides));
  });
  test('the reservation cannot have a second payment id', async () => {
    await assertSucceeds(selectLocal());
    await assertFails(selectLocal('client', {}, 'duplicate-payment'));
  });
  test('another client, owner or disabled account cannot select payment', async () => {
    for (const uid of ['otherClient', 'otherOwner', 'disabledClient']) {
      await assertFails(selectLocal(uid));
    }
  });
  test('a client cannot create a paid card record, even in a batch', async () => {
    await assertFails(selectLocal('client', {
      status: 'paid', paymentMethodId: 2, paymentMethodName: 'Tarjeta de crédito',
      paidAt: serverTimestamp(), receiptNumber: 'CARD-pay-reservation-1',
    }));
  });
  test('owner receives money atomically and another owner cannot do so', async () => {
    await assertSucceeds(selectLocal());
    await assertFails(receive('otherOwner'));
    await assertFails(receive('client'));
    await assertSucceeds(receive());
    const stored = await getDoc(doc(as('owner'), 'payments/pay-reservation-1'));
    if (stored.data().status !== 'paid') throw Error('Not paid');
  });
  test('owner can recover a local receipt when the pending document never reached Firebase', async () => {
    const db = as('owner');
    const batch = writeBatch(db);
    batch.set(doc(db, 'payments/pay-reservation-1'), payment({
      status: 'paid', paymentMethodId: 1, paymentMethodName: 'Efectivo',
      paidAt: serverTimestamp(), receiptNumber: 'LOCAL-pay-reservation-1',
    }));
    batch.update(doc(db, 'reservations/reservation-1'), {
      status: 'upcoming', paymentMethod: 'Efectivo', invoiceAccessStatus: 'pending',
      updatedAt: serverTimestamp(),
    });
    await assertSucceeds(batch.commit());
  });
  test('neither side can be confirmed independently', async () => {
    await assertSucceeds(selectLocal());
    await assertFails(updateDoc(doc(as('owner'), 'payments/pay-reservation-1'), {
      status: 'paid', paymentMethodId: 1, paymentMethodName: 'Efectivo',
      paidAt: serverTimestamp(), receiptNumber: 'LOCAL-pay-reservation-1',
      updatedAt: serverTimestamp(),
    }));
    await assertFails(updateDoc(doc(as('client'), 'reservations/reservation-1'), {
      status: 'upcoming', paymentMethod: 'Tarjeta', updatedAt: serverTimestamp(),
    }));
  });
  test('a stale pending retry cannot regress money already received', async () => {
    await selectLocal();
    await receive();
    await assertFails(selectLocal());
    await assertFails(updateDoc(doc(as('owner'), 'payments/pay-reservation-1'), {
      paidAt: Timestamp.fromMillis(1), updatedAt: serverTimestamp(),
    }));
  });
  test('a cancelled reservation cannot receive the pending payment', async () => {
    await selectLocal();
    await assertSucceeds(updateDoc(doc(as('client'), 'reservations/reservation-1'), {
      status: 'cancelled', cancellationReason: 'No puedo asistir', updatedAt: serverTimestamp(),
    }));
    await assertFails(receive());
  });
  test('an abandoned checkout cannot select the place after 15 minutes', async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await updateDoc(doc(ctx.firestore(), 'reservations/reservation-1'), {
        createdAt: Timestamp.fromMillis(Date.now() - 16 * 60 * 1000),
      });
    });
    await assertFails(selectLocal());
  });
  test('an already selected place remains retryable after 15 minutes', async () => {
    await selectLocal();
    await env.withSecurityRulesDisabled(async (ctx) => {
      await updateDoc(doc(ctx.firestore(), 'reservations/reservation-1'), {
        createdAt: Timestamp.fromMillis(Date.now() - 24 * 60 * 60 * 1000),
      });
    });
    await assertSucceeds(selectLocal());
  });
});
