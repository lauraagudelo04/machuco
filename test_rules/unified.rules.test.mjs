import { readFileSync } from 'node:fs';
import { test } from 'node:test';
import { initializeTestEnvironment, assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import { doc, setDoc, updateDoc, getDoc, serverTimestamp, Timestamp } from 'firebase/firestore';

test('reglas combinadas: moteles, habitaciones, suscripciones, reseñas y notificaciones', async () => {
  const env = await initializeTestEnvironment({ projectId: 'demo-machuco', firestore: {
    rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8'),
  }});
  try {
    await env.clearFirestore();
    await env.withSecurityRulesDisabled(async ctx => {
      for (const [uid, role] of [['owner', 'owner'], ['other', 'owner'], ['client', 'client'], ['admin', 'admin']]) {
        await setDoc(doc(ctx.firestore(), `users/${uid}`), { role, accountStatus: 'active' });
      }
    });
    const owner = env.authenticatedContext('owner').firestore();
    const other = env.authenticatedContext('other').firestore();
    const client = env.authenticatedContext('client').firestore();
    const admin = env.authenticatedContext('admin').firestore();
    await assertSucceeds(setDoc(doc(owner, 'motels/motel'), { ownerId: 'owner' }));
    await assertFails(updateDoc(doc(other, 'motels/motel'), { ownerId: 'other' }));
    const type = { id: 'type', motelId: 'motel', ownerId: 'owner', name: 'Suite', deleted: false, updatedAt: serverTimestamp() };
    await assertSucceeds(setDoc(doc(owner, 'room_types/type'), type));
    await assertFails(updateDoc(doc(other, 'room_types/type'), { ownerId: 'other', updatedAt: serverTimestamp() }));
    await assertSucceeds(setDoc(doc(owner, 'rooms/room'), {
      ...type, id: 'room', description: '', idType: 'type', pricePerHour: 100,
      roomNumber: '101', capacity: 2, imageUrls: [], isActive: true, includedServices: [],
    }));
    // Otro propietario también puede crear su motel, tipo y habitación.
    await assertSucceeds(setDoc(doc(other, 'motels/second'), { ownerId: 'other' }));
    const secondType = { ...type, id: 'second-type', motelId: 'second', ownerId: 'other' };
    await assertSucceeds(setDoc(doc(other, 'room_types/second-type'), secondType));
    await assertSucceeds(setDoc(doc(other, 'rooms/second-room'), {
      ...secondType, id: 'second-room', description: '', idType: 'second-type', pricePerHour: 100,
      roomNumber: '102', capacity: 2, imageUrls: [], isActive: true, includedServices: [],
    }));
    await assertFails(updateDoc(doc(other, 'rooms/room'), { ownerId: 'other', updatedAt: serverTimestamp() }));
    await assertFails(updateDoc(doc(owner, 'motels/motel'), { ownerId: 'other' }));
    // Un registro antiguo no autoriza sin el motel real en motels.
    await env.withSecurityRulesDisabled(async ctx => {
      await setDoc(doc(ctx.firestore(), 'room_motels/legacy'), { ownerId: 'owner' });
      await setDoc(doc(ctx.firestore(), 'users/9pojDLzLw3SL4S3VNK8JTPCUdbE2'), { role: 'owner', accountStatus: 'active' });
    });
    await assertFails(setDoc(doc(owner, 'room_types/legacy'), { ...type, id: 'legacy', motelId: 'legacy' }));
    const formerOwner = env.authenticatedContext('9pojDLzLw3SL4S3VNK8JTPCUdbE2').firestore();
    await assertFails(setDoc(doc(formerOwner, 'room_types/former'), {
      ...type, id: 'former', motelId: 'motel_1793753270427', ownerId: '9pojDLzLw3SL4S3VNK8JTPCUdbE2',
    }));
    const subscription = { localId: 1, planId: 1, planName: 'Plan', motelName: 'Motel', amount: 100,
      billingPeriod: 'monthly', nextBillingDate: Timestamp.now(), status: 'active', features: [], updatedAt: serverTimestamp() };
    await assertSucceeds(setDoc(doc(owner, 'users/owner/subscriptions/sub'), subscription));
    await assertFails(setDoc(doc(other, 'users/owner/subscriptions/sub'), subscription));
    await assertSucceeds(setDoc(doc(owner, 'subscriptions/owner'), { ...subscription, ownerId: 'owner' }));
    await assertFails(updateDoc(doc(owner, 'subscriptions/owner'), { localId: 2, updatedAt: serverTimestamp() }));
    await assertFails(setDoc(doc(other, 'subscriptions/owner'), { ...subscription, ownerId: 'other' }));
    const payment = { localId: 1, subscriptionLocalId: 1, date: Timestamp.now(), amount: 100,
      paymentMethod: 'Local', reference: 'ref', status: 'completed', updatedAt: serverTimestamp() };
    await assertSucceeds(setDoc(doc(owner, 'users/owner/subscriptions/sub/payments/pay'), payment));
    await assertSucceeds(setDoc(doc(owner, 'users/owner/subscriptions/sub/subscriptionPayments/pay'), payment));
    await assertSucceeds(setDoc(doc(owner, 'subscriptionPayments/pay'), { ...payment, ownerId: 'owner' }));
    await assertFails(setDoc(doc(owner, 'subscriptionPayments/bad'), { ...payment, ownerId: 'owner', subscriptionLocalId: 2 }));
    await assertFails(getDoc(doc(other, 'subscriptionPayments/pay')));
    await assertSucceeds(getDoc(doc(admin, 'users/owner/subscriptions/sub')));
    const review = { authorId: 'client', authorName: 'Cliente', title: 'Bien', body: 'Buena atención',
      rating: 5, date: Timestamp.now(), motelId: 'motel', type: 'motel', status: 'visible' };
    await assertSucceeds(setDoc(doc(client, 'reviews/review-client-client-1'), review));
    await assertFails(setDoc(doc(other, 'reviews/review-client-client-2'), review));
    await assertSucceeds(setDoc(doc(admin, 'notifications/global'), {
      eventType: 'system', actorUid: 'admin', target: 'all', title: 'Aviso', message: 'Mensaje', createdAt: serverTimestamp(),
    }));
    await assertSucceeds(getDoc(doc(client, 'notifications/global')));
    const targeted = {
      eventType: 'system', actorUid: 'admin', target: 'specificUser',
      recipientUid: 'client', recipientName: 'Cliente', recipientEmail: 'cliente@example.com',
      title: 'Aviso personal', message: 'Mensaje', createdAt: serverTimestamp(),
    };
    await assertSucceeds(setDoc(doc(admin, 'notifications/targeted'), targeted));
    await assertSucceeds(getDoc(doc(client, 'notifications/targeted')));
    await assertFails(getDoc(doc(other, 'notifications/targeted')));
    const { recipientEmail, ...missingEmail } = targeted;
    await assertFails(setDoc(doc(admin, 'notifications/incomplete'), missingEmail));

    await assertSucceeds(setDoc(doc(client, 'users/client/notificationReads/global'), { readAt: serverTimestamp() }));
    await assertSucceeds(setDoc(doc(client, 'users/client/devices/device'), { token: 'token', platform: 'android', updatedAt: serverTimestamp() }));
    await assertFails(setDoc(doc(other, 'users/client/devices/device'), { token: 'other', updatedAt: serverTimestamp() }));
  } finally { await env.cleanup(); }
});
