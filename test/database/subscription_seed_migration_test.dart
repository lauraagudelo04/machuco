import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:machuco/database/app_database.dart';
import 'package:machuco/database/migrations/suscripcion/subscription_test_owner_migration.dart';
import 'package:sqflite/sqflite.dart' as sqflite;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late String path;
  AppDatabase? database;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('subscription_seed_');
    path = '${directory.path}/machuco.db';
  });

  tearDown(() async {
    await database?.close();
    database = null;
    await directory.delete(recursive: true);
  });

  Future<void> expectSeed() async {
    final subscription = await database!.subscriptionDao.findByEmail(
      'propietario.test@machuco.com',
    );
    expect(subscription?.planId, 2);
    expect(subscription?.planName, 'Premium');
    expect(subscription?.amount, 150000);
    expect(subscription?.billingPeriod, 'Mensual');
    expect(subscription?.features, ['Gestión de habitaciones', 'Reportes']);
    expect(await database!.database.getVersion(), 11);
    expect(
      await database!.database.rawQuery('PRAGMA foreign_key_check'),
      isEmpty,
    );
    expect(
      await database!.subscriptionDao.findPayments(subscription!.id!),
      isEmpty,
    );
  }

  test(
    'una instalación nueva tiene las tablas y la suscripción de prueba',
    () async {
      database = await AppDatabaseProvider.open(name: path);
      await expectSeed();
    },
  );

  test(
    'una base v6 recibe el seed al migrar y no lo duplica al reabrir',
    () async {
      database = await AppDatabaseProvider.open(name: path);
      await database!.database.delete('subscriptions');
      await database!.database.setVersion(6);
      await database!.close();
      database = await AppDatabaseProvider.open(name: path);
      await expectSeed();
      await database!.close();
      database = await AppDatabaseProvider.open(name: path);
      expect(await database!.database.query('subscriptions'), hasLength(1));
    },
  );

  test('migrar conserva la suscripción existente y sus pagos', () async {
    database = await AppDatabaseProvider.open(name: path);
    final db = database!.database as sqflite.Database;
    final subscription = (await db.query('subscriptions')).single;
    await db.update('subscriptions', {'amount': 230000});
    await db.insert('subscription_payments', {
      'subscriptionId': subscription['id'],
      'date': 1793509200000000,
      'amount': 230000,
      'paymentMethod': 'PSE',
      'reference': 'EXISTING',
      'status': 'completed',
    });
    await db.setVersion(6);
    await database!.close();
    database = await AppDatabaseProvider.open(name: path);
    final reopened = database!.database as sqflite.Database;
    await seedSubscriptionTestOwner(reopened);
    final rows = await reopened.query('subscriptions');
    expect(rows, hasLength(1));
    expect(rows.single['id'], subscription['id']);
    expect(rows.single['amount'], 230000);
    expect(
      (await reopened.query('subscription_payments')).single['reference'],
      'EXISTING',
    );
    expect(await reopened.rawQuery('PRAGMA foreign_key_check'), isEmpty);
  });
}
