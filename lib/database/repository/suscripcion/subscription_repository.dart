import 'dart:convert';

import 'package:floor/floor.dart';
import 'package:http/http.dart' as http;
import 'package:machuco/database/app_database.dart';
import 'package:machuco/database/model/suscripcion/subscription.dart';

/// Todas las consultas SQLite de esta funcionalidad viven en este archivo.
@dao
abstract class SubscriptionDao {
  @Query('SELECT * FROM subscriptions WHERE id = :id LIMIT 1')
  Future<SubscriptionDetails?> findById(int id);

  @Query('SELECT * FROM subscriptions ORDER BY id LIMIT 1')
  Future<SubscriptionDetails?> findFirst();

  @Query(
    'SELECT * FROM subscriptions WHERE userEmail = :email ORDER BY id LIMIT 1',
  )
  Future<SubscriptionDetails?> findByEmail(String email);

  @insert
  Future<int> insertSubscription(SubscriptionDetails subscription);

  @update
  Future<int> updateSubscription(SubscriptionDetails subscription);

  @Query(
    'SELECT * FROM subscription_payments WHERE subscriptionId = :subscriptionId ORDER BY date DESC, id DESC',
  )
  Future<List<SubscriptionPayment>> findPayments(int subscriptionId);

  @insert
  Future<int> insertPayment(SubscriptionPayment payment);
}

class SubscriptionRepositoryException implements Exception {
  const SubscriptionRepositoryException(this.message);
  final String message;
}

/// Único repositorio de suscripción: consultas SQLite y catálogo de Supabase.
class SubscriptionRepository {
  SubscriptionRepository({
    AppDatabase? database,
    http.Client? client,
    String? supabaseUrl,
    String? publishableKey,
  }) : _database = database == null
           ? AppDatabaseProvider.database
           : Future.value(database),
       _get = client?.get ?? http.get,
       _supabaseUrl =
           supabaseUrl ??
           const String.fromEnvironment(
             'SUPABASE_URL',
             defaultValue: 'https://ogrbbuwtsyezegkpwtsl.supabase.co',
           ),
       _publishableKey =
           publishableKey ??
           const String.fromEnvironment(
             'SUPABASE_PUBLISHABLE_KEY',
             defaultValue: 'sb_publishable_Wv16MVxsTzA89lBeocarLQ_YL33Ya_E',
           );

  final Future<AppDatabase> _database;
  final Future<http.Response> Function(Uri, {Map<String, String>? headers})
  _get;
  final String _supabaseUrl;
  final String _publishableKey;

  Future<List<SubscriptionPlan>> findPlans() async {
    final base = Uri.tryParse(_supabaseUrl);
    if (base == null ||
        base.scheme != 'https' ||
        base.host.isEmpty ||
        _publishableKey.isEmpty) {
      throw const SubscriptionRepositoryException(
        'La consulta de planes no está configurada.',
      );
    }
    final uri = base.replace(
      path: '/rest/v1/subscription_plans',
      queryParameters: {'select': 'id,name', 'order': 'id.asc'},
    );
    late final http.Response response;
    try {
      response = await _get(
        uri,
        headers: {'apikey': _publishableKey, 'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 15));
    } catch (_) {
      throw const SubscriptionRepositoryException(
        'No se pudo conectar con el catálogo de planes.',
      );
    }
    if (response.statusCode != 200) {
      throw const SubscriptionRepositoryException(
        'No se pudieron consultar los planes en Supabase.',
      );
    }
    try {
      final rows = jsonDecode(utf8.decode(response.bodyBytes));
      if (rows is! List) throw const FormatException('Respuesta inválida');
      return rows
          .map((row) => SubscriptionPlan.fromJson(row as Map<String, dynamic>))
          .toList();
    } on FormatException {
      throw const SubscriptionRepositoryException(
        'El catálogo de planes devolvió datos inválidos.',
      );
    } on TypeError {
      throw const SubscriptionRepositoryException(
        'El catálogo de planes devolvió datos inválidos.',
      );
    }
  }

  Future<SubscriptionDetails?> findSubscription(
    int? id, {
    List<SubscriptionPlan>? plans,
  }) async {
    final dao = (await _database).subscriptionDao;
    final subscription = id == null
        ? await dao.findFirst()
        : await dao.findById(id);
    return _resolvePlanName(subscription, plans: plans);
  }

  Future<SubscriptionDetails?> findSubscriptionByEmail(
    String email, {
    List<SubscriptionPlan>? plans,
  }) async {
    final dao = (await _database).subscriptionDao;
    final subscription = await dao.findByEmail(email.trim().toLowerCase());
    return _resolvePlanName(subscription, plans: plans);
  }

  Future<SubscriptionDetails?> _resolvePlanName(
    SubscriptionDetails? subscription, {
    List<SubscriptionPlan>? plans,
  }) async {
    if (subscription == null) return null;
    if (subscription.planId == null) {
      throw const SubscriptionRepositoryException(
        'La suscripción aún no tiene un plan asignado.',
      );
    }
    final catalogue = plans ?? await findPlans();
    final matches = catalogue.where((plan) => plan.id == subscription.planId);
    if (matches.isEmpty) {
      throw const SubscriptionRepositoryException(
        'El plan de esta suscripción no aparece en el catálogo.',
      );
    }
    final refreshed = _withOwnerAndPlan(
      subscription,
      email: subscription.userEmail,
      plan: matches.first,
    );
    await (await _database).subscriptionDao.updateSubscription(refreshed);
    return refreshed;
  }

  /// Registra una asociación explícita; consultar no asigna planes automáticamente.
  Future<int> saveSubscription(SubscriptionDetails subscription) async {
    final email = subscription.userEmail?.trim().toLowerCase();
    if (subscription.planId == null) {
      throw ArgumentError('La suscripción requiere el ID del plan');
    }
    final plans = await findPlans();
    final matches = plans.where((plan) => plan.id == subscription.planId);
    if (matches.isEmpty) throw ArgumentError('El plan no existe en Supabase');
    final dao = (await _database).subscriptionDao;
    final ownerSubscription = email == null || email.isEmpty
        ? null
        : await dao.findByEmail(email);
    if (ownerSubscription != null && ownerSubscription.id != subscription.id) {
      throw StateError('El correo ya tiene una suscripción registrada');
    }
    final saved = _withOwnerAndPlan(
      subscription,
      email: email,
      plan: matches.first,
    );
    final id = subscription.id;
    if (id == null || await dao.findById(id) == null) {
      return dao.insertSubscription(saved);
    } else {
      await dao.updateSubscription(saved);
      return id;
    }
  }

  SubscriptionDetails _withOwnerAndPlan(
    SubscriptionDetails subscription, {
    required String? email,
    required SubscriptionPlan plan,
  }) => SubscriptionDetails(
    id: subscription.id,
    userEmail: email,
    planId: plan.id,
    planName: plan.name,
    motelName: subscription.motelName,
    amount: subscription.amount,
    billingPeriod: subscription.billingPeriod,
    nextBillingDate: subscription.nextBillingDate,
    status: subscription.status,
    features: subscription.features,
  );

  Future<List<SubscriptionPayment>> findPayments(int subscriptionId) async =>
      (await _database).subscriptionDao.findPayments(subscriptionId);

  Future<SubscriptionPayment> savePayment(SubscriptionPayment payment) async {
    final id = await (await _database).subscriptionDao.insertPayment(payment);
    return SubscriptionPayment(
      id: id,
      subscriptionId: payment.subscriptionId,
      date: payment.date,
      amount: payment.amount,
      paymentMethod: payment.paymentMethod,
      reference: payment.reference,
      status: payment.status,
    );
  }
}
