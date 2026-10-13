import 'dart:convert';
import 'dart:io';

import 'package:floor/floor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:machuco/controllers/subscription/owner_subscription_controller.dart';
import 'package:machuco/core/design_system/components/status_badge.dart';
import 'package:machuco/database/app_database.dart';
import 'package:machuco/database/model/suscripcion/subscription.dart';
import 'package:machuco/database/repository/suscripcion/subscription_repository.dart';
import 'package:sqflite/sqflite.dart' as sqflite;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late String path;
  AppDatabase? database;
  final controllers = <OwnerSubscriptionController>[];
  final clients = <http.Client>[];

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('machuco_subscription_');
    path = '${directory.path}${Platform.pathSeparator}subscriptions.db';
  });

  tearDown(() async {
    for (final controller in controllers) {
      controller.dispose();
    }
    controllers.clear();
    for (final client in clients) {
      client.close();
    }
    clients.clear();
    await database?.close();
    database = null;
    await directory.delete(recursive: true);
  });

  SubscriptionDetails subscription({
    int? id = 1,
    String email = 'owner@example.com',
    int planId = 2,
  }) => SubscriptionDetails(
    id: id,
    userEmail: email,
    planId: planId,
    planName: 'Nombre local anterior',
    motelName: 'Motel Machuco',
    amount: 150000,
    billingPeriod: 'Mensual',
    nextBillingDate: DateTime(2026, 11, 1),
    status: AppStatus.active,
    features: const ['Beneficio de prueba'],
  );

  SubscriptionRepository repository({http.Client? client}) {
    final effectiveClient =
        client ??
        MockClient(
          (request) async => http.Response(
            '[{"id":1,"name":"Basico"},{"id":2,"name":"Premium"}]',
            200,
          ),
        );
    clients.add(effectiveClient);
    return SubscriptionRepository(database: database!, client: effectiveClient);
  }

  Future<OwnerSubscriptionController> controller(
    SubscriptionRepository repository, {
    int? subscriptionId = 1,
  }) async {
    final result = OwnerSubscriptionController(
      repository: repository,
      subscriptionId: subscriptionId,
    );
    controllers.add(result);
    await result.ready;
    return result;
  }

  test(
    'consulta Supabase, resuelve el plan de SQLite y conserva pagos al reabrir',
    () async {
      database = await AppDatabaseProvider.open(name: path);
      final repo = repository(
        client: MockClient((request) async {
          expect(request.url.path, '/rest/v1/subscription_plans');
          expect(request.url.queryParameters['select'], 'id,name');
          expect(request.url.queryParameters.containsKey('apikey'), isFalse);
          expect(request.headers['apikey'], startsWith('sb_publishable_'));
          return http.Response(
            '[{"id":1,"name":"Basico"},{"id":2,"name":"Premium"}]',
            200,
          );
        }),
      );
      await repo.saveSubscription(subscription(email: ' OWNER@EXAMPLE.COM '));
      final current = await controller(repo);
      expect(current.errorMessage, isNull);
      expect(current.subscription?.planName, 'Premium');
      expect(current.subscription?.amount, 150000);
      expect(current.plans.map((plan) => plan.name), ['Basico', 'Premium']);

      await current.addPayment(
        amount: 125000,
        paymentMethod: 'Transferencia',
        reference: 'FIRST',
      );
      await current.addPayment(
        amount: 150000,
        paymentMethod: 'PSE',
        reference: 'SECOND',
      );
      await database!.close();
      database = await AppDatabaseProvider.open(name: path);
      final reopened = await controller(repository());
      expect(reopened.payments.map((payment) => payment.reference), [
        'SECOND',
        'FIRST',
      ]);
      expect(reopened.payments.map((payment) => payment.id), [2, 1]);
      expect(reopened.payments.last.date, current.payments.last.date);
      expect(reopened.payments.last.status, AppStatus.completed);
      expect(reopened.subscription?.nextBillingDate, DateTime(2026, 11, 1));
      expect(reopened.subscription?.features, ['Beneficio de prueba']);
    },
  );

  test('genera IDs de suscripción 1 y 2 cuando no se indica un ID', () async {
    database = await AppDatabaseProvider.open(name: path);
    final repo = repository();
    final firstId = await repo.saveSubscription(
      subscription(id: null, email: 'first@example.com'),
    );
    final secondId = await repo.saveSubscription(
      subscription(id: null, email: 'second@example.com'),
    );
    expect(firstId, 1);
    expect(secondId, 2);
    expect((await database!.subscriptionDao.findById(1))?.id, 1);
    expect((await database!.subscriptionDao.findById(2))?.id, 2);
  });

  test(
    'cada ID consulta exclusivamente su suscripción y su historial',
    () async {
      database = await AppDatabaseProvider.open(name: path);
      final repo = repository();
      await repo.saveSubscription(subscription());
      await repo.saveSubscription(
        subscription(id: 2, email: 'other@example.com', planId: 1),
      );
      final first = await controller(repo);
      await first.addPayment(
        amount: 150000,
        paymentMethod: 'PSE',
        reference: 'OWNER',
      );
      final second = await controller(repo, subscriptionId: 2);
      expect(second.subscription?.planName, 'Basico');
      expect(second.payments, isEmpty);
      await second.addPayment(
        amount: 50000,
        paymentMethod: 'PSE',
        reference: 'OTHER',
      );
      expect(second.payments.single.reference, 'OTHER');
      await first.load();
      expect(first.subscription?.id, 1);
      expect(first.payments.single.reference, 'OWNER');
    },
  );

  test(
    'una base sin suscripción muestra el catálogo sin asignar un plan',
    () async {
      database = await AppDatabaseProvider.open(name: path);
      final repo = repository();
      final current = await controller(repo);
      expect(current.subscription, isNull);
      expect(current.errorMessage, isNull);
      expect(current.plans, hasLength(2));
      expect(await repo.findSubscriptionByEmail('owner@example.com'), isNull);
      await expectLater(
        current.addPayment(
          amount: 1,
          paymentMethod: 'PSE',
          reference: 'NO-SUB',
        ),
        throwsStateError,
      );
    },
  );

  test(
    'sin ID indicado consulta la primera suscripción guardada en SQLite',
    () async {
      database = await AppDatabaseProvider.open(name: path);
      final repo = repository();
      await repo.saveSubscription(subscription());
      final current = await controller(repo, subscriptionId: null);
      expect(current.errorMessage, isNull);
      expect(current.subscription?.id, 1);
      expect(current.subscription?.planName, 'Premium');
      expect(current.payments, isEmpty);
    },
  );

  test('una escritura fallida no agrega pagos al historial', () async {
    database = await AppDatabaseProvider.open(name: path);
    final client = MockClient(
      (_) async => http.Response('[{"id":2,"name":"Premium"}]', 200),
    );
    clients.add(client);
    final repo = _FailingRepository(database!, client);
    await repo.saveSubscription(subscription());
    final current = await controller(repo);
    await expectLater(
      current.addPayment(
        amount: 150000,
        paymentMethod: 'PSE',
        reference: 'FAILED',
      ),
      throwsStateError,
    );
    expect(current.payments, isEmpty);
    expect(current.isSaving, isFalse);
    expect(await repo.findPayments(1), isEmpty);
  });

  test(
    'errores y respuestas inválidas de Supabase no inventan planes',
    () async {
      database = await AppDatabaseProvider.open(name: path);
      for (final response in [
        http.Response('{}', 200),
        http.Response('[]', 401),
      ]) {
        final repo = repository(client: MockClient((_) async => response));
        await expectLater(
          repo.findPlans(),
          throwsA(isA<SubscriptionRepositoryException>()),
        );
      }
      expect(
        await repository(
          client: MockClient((_) async => http.Response('[]', 200)),
        ).findPlans(),
        isEmpty,
      );
    },
  );

  test(
    'migra SQLite v2 conservando pagos y sin asignar el ejemplo a un usuario',
    () async {
      final previous = await sqfliteDatabaseFactory.openDatabase(
        path,
        options: sqflite.OpenDatabaseOptions(
          version: 2,
          onCreate: (db, _) async {
            await db.execute(
              'CREATE TABLE subscriptions (id TEXT NOT NULL PRIMARY KEY, '
              'planName TEXT NOT NULL, motelName TEXT NOT NULL, amount INTEGER NOT NULL, '
              'billingPeriod TEXT NOT NULL, nextBillingDate INTEGER NOT NULL, status TEXT NOT NULL, features TEXT NOT NULL)',
            );
            await db.execute(
              'CREATE TABLE subscription_payments (id TEXT NOT NULL PRIMARY KEY, '
              'subscriptionId TEXT NOT NULL, date INTEGER NOT NULL, amount INTEGER NOT NULL, '
              'paymentMethod TEXT NOT NULL, reference TEXT NOT NULL, status TEXT NOT NULL)',
            );
            await db.insert('subscriptions', {
              'id': 'sub-001',
              'planName': 'Plan anterior',
              'motelName': 'Motel',
              'amount': 150000,
              'billingPeriod': 'Mensual',
              'nextBillingDate': DateTime(2026, 11, 1).microsecondsSinceEpoch,
              'status': 'active',
              'features': jsonEncode(['Beneficio']),
            });
            await db.insert('subscription_payments', {
              'id': 'old-pay',
              'subscriptionId': 'sub-001',
              'date': DateTime(2026, 10, 1).microsecondsSinceEpoch,
              'amount': 150000,
              'paymentMethod': 'PSE',
              'reference': 'EXISTING',
              'status': 'completed',
            });
          },
        ),
      );
      await previous.close();
      database = await AppDatabaseProvider.open(name: path);
      final repo = repository();
      expect((await database!.subscriptionDao.findById(1))?.userEmail, isNull);
      expect(await repo.findSubscriptionByEmail('owner@example.com'), isNull);
      expect((await repo.findPayments(1)).single.reference, 'EXISTING');
      await repo.saveSubscription(subscription());
      expect(
        (await repo.findSubscriptionByEmail('owner@example.com'))?.planName,
        'Premium',
      );
      expect((await repo.findPayments(1)).single.reference, 'EXISTING');
      final newPayment = await repo.savePayment(
        SubscriptionPayment(
          subscriptionId: 1,
          date: DateTime.now(),
          amount: 150000,
          paymentMethod: 'PSE',
          reference: 'NEW',
          status: AppStatus.completed,
        ),
      );
      expect(newPayment.id, 2);
      expect(
        await database!.database.rawQuery('PRAGMA foreign_key_check'),
        isEmpty,
      );
    },
  );
}

class _FailingRepository extends SubscriptionRepository {
  _FailingRepository(AppDatabase database, http.Client client)
    : super(database: database, client: client);
  @override
  Future<SubscriptionPayment> savePayment(SubscriptionPayment payment) async {
    throw StateError('Escritura fallida');
  }
}
