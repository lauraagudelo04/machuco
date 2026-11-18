import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:machuco/core/design_system/components/status_badge.dart';
import 'package:machuco/database/model/suscripcion/subscription.dart';
import 'package:machuco/service/firebase/firestore_collections.dart';

/// Sincroniza exclusivamente las colecciones raíz `subscriptions` y
/// `subscriptionPayments`. No toca
/// la colección raíz `payments`, que pertenece a los pagos de reservas.
class SubscriptionFirestoreRepository {
  SubscriptionFirestoreRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  /// Resultado remoto de la suscripción del propietario autenticado.
  ///
  /// La pantalla no usa SQLite para decidir qué suscripción pertenece a la
  /// sesión. Firestore es la fuente de verdad y los pagos se leen de la
  /// subcolección de esa misma suscripción.
  Future<
    ({SubscriptionDetails subscription, List<SubscriptionPayment> payments})?
  >
  findByEmail(String email, {List<SubscriptionPlan>? plans}) async {
    final uid = _requireUid();
    final normalizedEmail = email.trim().toLowerCase();
    if (normalizedEmail.isEmpty) return null;

    final subscriptionRef = _firestore
        .collection(FirestoreCollections.subscriptions)
        .doc(uid);
    final profileSnapshot = await _firestore
        .collection(FirestoreCollections.users)
        .doc(uid)
        .get();
    final profileData = profileSnapshot.data();
    final profileEmail = profileData?['email'];
    if (profileEmail is String &&
        profileEmail.trim().toLowerCase() != normalizedEmail) {
      return null;
    }
    final profilePlanId = _intValue(profileData?['planId']);
    final subscriptionSnapshot = await subscriptionRef.get();
    final subscriptionData = subscriptionSnapshot.data();
    if (!subscriptionSnapshot.exists || subscriptionData == null) {
      if (profilePlanId == null) return null;
      final matchingPlans = plans
          ?.where((plan) => plan.id == profilePlanId)
          .toList();
      if (matchingPlans == null || matchingPlans.isEmpty) return null;
      return (
        subscription: _subscriptionFromPlan(
          profileEmail is String ? profileEmail : normalizedEmail,
          matchingPlans.first,
        ),
        payments: <SubscriptionPayment>[],
      );
    }

    final subscription = _subscriptionFromFirestore(
      subscriptionData,
      fallbackEmail: normalizedEmail,
      plans: plans,
    );
    final paymentsSnapshot = await _firestore
        .collection(FirestoreCollections.subscriptionPayments)
        .where('ownerId', isEqualTo: uid)
        .get();
    final payments = paymentsSnapshot.docs
        .map((payment) => _paymentFromFirestore(payment.data()))
        .where((payment) => payment.subscriptionId == subscription.id)
        .toList()
      ..sort((left, right) {
        final byDate = right.date.compareTo(left.date);
        return byDate != 0 ? byDate : (right.id ?? 0).compareTo(left.id ?? 0);
      });

    return (subscription: subscription, payments: payments);
  }

  Future<void> sync({
    required SubscriptionDetails subscription,
    required List<SubscriptionPayment> payments,
  }) async {
    final uid = _requireUid();
    final subscriptionId = subscription.id;
    if (subscriptionId == null) {
      throw StateError('La suscripción debe tener un ID local.');
    }

    final subscriptionRef = _firestore
        .collection(FirestoreCollections.subscriptions)
        .doc(uid);
    final subscriptionData = <String, dynamic>{
      'ownerId': uid,
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
        final paymentRef = _firestore
            .collection(FirestoreCollections.subscriptionPayments)
            .doc('${uid}_$paymentId');
        batch.set(paymentRef, {
          'ownerId': uid,
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

  String _requireUid() {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      throw StateError('No hay un usuario autenticado para consultar la suscripción.');
    }
    return uid;
  }

  SubscriptionDetails _subscriptionFromFirestore(
    Map<String, dynamic> data, {
    required String fallbackEmail,
    List<SubscriptionPlan>? plans,
  }) {
    final localId = _intValue(data['localId']);
    final planId = _intValue(data['planId']);
    final nextBillingDate = _dateValue(data['nextBillingDate']);
    final status = _statusValue(data['status']);
    if (localId == null ||
        planId == null ||
        nextBillingDate == null ||
        status == null) {
      throw const FormatException(
        'La suscripción de Firestore tiene datos inválidos.',
      );
    }

    final matchingPlans = plans?.where((plan) => plan.id == planId).toList();
    final planName = matchingPlans != null && matchingPlans.isNotEmpty
        ? matchingPlans.first.name
        : _requiredString(data['planName'], 'planName');
    return SubscriptionDetails(
      id: localId,
      userEmail: _optionalString(data['userEmail']) ?? fallbackEmail,
      planId: planId,
      planName: planName,
      motelName: _requiredString(data['motelName'], 'motelName'),
      amount: _positiveInt(data['amount'], 'amount'),
      billingPeriod: _requiredString(data['billingPeriod'], 'billingPeriod'),
      nextBillingDate: nextBillingDate,
      status: status,
      features: _stringList(data['features'], 'features'),
    );
  }

  SubscriptionDetails _subscriptionFromPlan(
    String email,
    SubscriptionPlan plan,
  ) {
    final price = plan.price;
    if (price == null || price <= 0) {
      throw const FormatException(
        'El plan de Supabase no tiene un precio válido.',
      );
    }
    final features = plan.features.isEmpty
        ? const [
            'Administración de moteles',
            'Gestión de habitaciones',
            'Gestión de reservas',
            'Registro y consulta de pagos',
          ]
        : plan.features;
    return SubscriptionDetails(
      id: plan.id,
      userEmail: email.trim().toLowerCase(),
      planId: plan.id,
      planName: plan.name,
      motelName: 'Motel del propietario',
      amount: price,
      billingPeriod: _billingLabel(plan.billingPeriod),
      nextBillingDate: _nextBillingDate(plan.billingPeriod),
      status: AppStatus.active,
      features: features,
    );
  }

  static String _billingLabel(String value) => switch (value.toLowerCase()) {
    'yearly' || 'annual' || 'anual' => 'Anual',
    _ => 'Mensual',
  };

  static DateTime _nextBillingDate(String value) {
    final now = DateTime.now();
    if (value.toLowerCase() == 'yearly' || value.toLowerCase() == 'annual') {
      return DateTime(now.year + 1, now.month, now.day);
    }
    return DateTime(now.year, now.month + 1, now.day);
  }

  SubscriptionPayment _paymentFromFirestore(Map<String, dynamic> data) {
    final localId = _intValue(data['localId']);
    final subscriptionLocalId = _intValue(data['subscriptionLocalId']);
    final date = _dateValue(data['date']);
    final status = _statusValue(data['status']);
    if (localId == null ||
        subscriptionLocalId == null ||
        date == null ||
        status == null) {
      throw const FormatException(
        'El pago de suscripción tiene datos inválidos.',
      );
    }
    return SubscriptionPayment(
      id: localId,
      subscriptionId: subscriptionLocalId,
      date: date,
      amount: _positiveInt(data['amount'], 'amount'),
      paymentMethod: _requiredString(data['paymentMethod'], 'paymentMethod'),
      reference: _requiredString(data['reference'], 'reference'),
      status: status,
    );
  }

  static int? _intValue(Object? value) => switch (value) {
    int() => value,
    num() => value.toInt(),
    String() => int.tryParse(value),
    _ => null,
  };

  static int _positiveInt(Object? value, String field) {
    final parsed = _intValue(value);
    if (parsed == null || parsed <= 0) {
      throw FormatException('El campo $field no es válido.');
    }
    return parsed;
  }

  static DateTime? _dateValue(Object? value) => switch (value) {
    Timestamp() => value.toDate(),
    DateTime() => value,
    _ => null,
  };

  static AppStatus? _statusValue(Object? value) {
    if (value is! String) return null;
    for (final status in AppStatus.values) {
      if (status.name == value) return status;
    }
    return null;
  }

  static String _requiredString(Object? value, String field) {
    final text = value is String ? value.trim() : '';
    if (text.isEmpty) throw FormatException('El campo $field no es válido.');
    return text;
  }

  static String? _optionalString(Object? value) {
    final text = value is String ? value.trim() : '';
    return text.isEmpty ? null : text.toLowerCase();
  }

  static List<String> _stringList(Object? value, String field) {
    if (value is! List || value.any((item) => item is! String)) {
      throw FormatException('El campo $field no es válido.');
    }
    return value.cast<String>();
  }
}
