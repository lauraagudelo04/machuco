import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:machuco/database/model/suscripcion/subscription.dart';
import 'package:machuco/service/firebase/firestore_collections.dart';

class SubscriptionFirestoreRepository {
  SubscriptionFirestoreRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  Future<void> sync({
    required SubscriptionDetails subscription,
    required List<SubscriptionPayment> payments,
  }) async {
    final uid = _auth.currentUser?.uid;
    final subscriptionId = subscription.id;
    if (uid == null || uid.isEmpty) {
      throw StateError('No hay un usuario autenticado para sincronizar.');
    }
    if (subscriptionId == null) {
      throw StateError('La suscripción debe tener un ID local.');
    }

    final subscriptionRef = _firestore
        .collection(FirestoreCollections.users)
        .doc(uid)
        .collection(FirestoreCollections.subscriptions)
        .doc(subscriptionId.toString());
    final subscriptionData = <String, dynamic>{
      'localId': subscriptionId,
      'userEmail': subscription.userEmail,
      'planId': subscription.planId,
      'planName': subscription.planName,
      'motelName': subscription.motelName,
      'amount': subscription.amount,
      'billingPeriod': subscription.billingPeriod,
      'nextBillingDate': Timestamp.fromDate(subscription.nextBillingDate),
      'status': subscription.status.name,
      'features': subscription.features,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    for (var start = 0; start < payments.length || start == 0; start += 450) {
      final batch = _firestore.batch();
      if (start == 0) {
        batch.set(subscriptionRef, subscriptionData, SetOptions(merge: true));
      }
      final end = start + 450 < payments.length ? start + 450 : payments.length;
      for (final payment in payments.sublist(start, end)) {
        final paymentId = payment.id;
        if (paymentId == null) continue;
        final paymentRef = subscriptionRef
            .collection(FirestoreCollections.payments)
            .doc(paymentId.toString());
        batch.set(paymentRef, {
          'localId': paymentId,
          'subscriptionLocalId': payment.subscriptionId,
          'date': Timestamp.fromDate(payment.date),
          'amount': payment.amount,
          'paymentMethod': payment.paymentMethod,
          'reference': payment.reference,
          'status': payment.status.name,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      await batch.commit();
      if (end == payments.length) break;
    }
  }
}
