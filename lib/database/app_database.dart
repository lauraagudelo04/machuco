// ignore_for_file: experimental_member_use

import 'dart:async';

import 'package:floor/floor.dart';
import 'package:machuco/database/model/client/client.dart';
import 'package:machuco/database/model/suscripcion/subscription.dart';
import 'package:machuco/database/repository/client/client_repository.dart';
import 'package:machuco/database/repository/suscripcion/subscription_repository.dart';
import 'package:machuco/database/model/phone_country_code/phone_country_code.dart'; // Añadir import
import 'package:machuco/database/repository/phone_country_code/phone_country_code_repository.dart'; // Añadir import
import 'package:sqflite/sqflite.dart' as sqflite;

part 'app_database.g.dart';

@TypeConverters([
  SubscriptionDateConverter,
  SubscriptionStatusConverter,
  SubscriptionFeaturesConverter,
])
@Database(version: 6, entities: [SubscriptionDetails, SubscriptionPayment, Client, PhoneCountryCode])
abstract class AppDatabase extends FloorDatabase {
  SubscriptionDao get subscriptionDao;
  ClientDao get clientDao;
  PhoneCountryCodeDao get phoneCountryCodeDao;
}

class AppDatabaseProvider {
  static Future<AppDatabase>? _database;

  static Future<AppDatabase> get database => _database ??= open();

  static Future<AppDatabase> open({
    String name = const String.fromEnvironment(
      'SQLITE_DATABASE_PATH',
      defaultValue: 'machuco.db',
    ),
  }) => $FloorAppDatabase.databaseBuilder(name).addMigrations([
    migration1To2,
    migration2To3,
    migration3To4,
    migration4To5,
    migration5To6,
  ]).build();
}

final migration1To2 = Migration(1, 2, (database) async {
  await database.execute(
    'CREATE TABLE IF NOT EXISTS subscriptions ('
    'id TEXT NOT NULL PRIMARY KEY, planName TEXT NOT NULL, '
    'motelName TEXT NOT NULL, amount INTEGER NOT NULL, '
    'billingPeriod TEXT NOT NULL, nextBillingDate INTEGER NOT NULL, '
    'status TEXT NOT NULL, features TEXT NOT NULL)',
  );
  await database.execute(
    'CREATE TABLE IF NOT EXISTS subscription_payments ('
    'id TEXT NOT NULL PRIMARY KEY, subscriptionId TEXT NOT NULL, '
    'date INTEGER NOT NULL, amount INTEGER NOT NULL, '
    'paymentMethod TEXT NOT NULL, reference TEXT NOT NULL, status TEXT NOT NULL, '
    'FOREIGN KEY (subscriptionId) REFERENCES subscriptions (id))',
  );
  await database.execute(
    'CREATE INDEX IF NOT EXISTS index_subscription_payments_subscriptionId '
    'ON subscription_payments (subscriptionId)',
  );
  await database.execute('DROP TABLE IF EXISTS clients');
});

final migration2To3 = Migration(2, 3, (database) async {
  await database.execute('ALTER TABLE subscriptions ADD COLUMN userEmail TEXT');
  await database.execute('ALTER TABLE subscriptions ADD COLUMN planId INTEGER');
});

/// Reasigna IDs enteros conservando los datos y los vínculos de los pagos.
final migration3To4 = Migration(3, 4, (database) async {
  final subscriptions = await database.query('subscriptions', orderBy: 'id');
  final payments = await database.query(
    'subscription_payments',
    orderBy: 'date, id',
  );
  await database.execute(
    'CREATE TABLE subscriptions_new ('
    'id INTEGER PRIMARY KEY AUTOINCREMENT, userEmail TEXT, planId INTEGER, '
    'planName TEXT NOT NULL, motelName TEXT NOT NULL, amount INTEGER NOT NULL, '
    'billingPeriod TEXT NOT NULL, nextBillingDate INTEGER NOT NULL, '
    'status TEXT NOT NULL, features TEXT NOT NULL)',
  );
  await database.execute(
    'CREATE TABLE subscription_payments_new ('
    'id INTEGER PRIMARY KEY AUTOINCREMENT, subscriptionId INTEGER NOT NULL, '
    'date INTEGER NOT NULL, amount INTEGER NOT NULL, paymentMethod TEXT NOT NULL, '
    'reference TEXT NOT NULL, status TEXT NOT NULL, '
    'FOREIGN KEY (subscriptionId) REFERENCES subscriptions_new (id))',
  );
  final newIds = <String, int>{};
  for (final subscription in subscriptions) {
    final row = Map<String, Object?>.of(subscription);
    final previousId = row.remove('id').toString();
    newIds[previousId] = await database.insert('subscriptions_new', row);
  }
  for (final payment in payments) {
    final row = Map<String, Object?>.of(payment)..remove('id');
    final newSubscriptionId = newIds[row['subscriptionId'].toString()];
    if (newSubscriptionId == null) {
      throw StateError(
        'Se encontró un pago sin suscripción durante la migración',
      );
    }
    row['subscriptionId'] = newSubscriptionId;
    await database.insert('subscription_payments_new', row);
  }
  await database.execute('DROP TABLE subscription_payments');
  await database.execute('DROP TABLE subscriptions');
  await database.execute(
    'ALTER TABLE subscriptions_new RENAME TO subscriptions',
  );
  await database.execute(
    'ALTER TABLE subscription_payments_new RENAME TO subscription_payments',
  );
  await database.execute(
    'CREATE INDEX index_subscription_payments_subscriptionId '
    'ON subscription_payments (subscriptionId)',
  );
});
final migration4To5 = Migration(4, 5, (database) async {
  await database.execute(
    'CREATE TABLE IF NOT EXISTS `clients` ('
    '`id` INTEGER PRIMARY KEY AUTOINCREMENT, '
    '`name` TEXT NOT NULL, '
    '`phone` TEXT NOT NULL, '
    '`email` TEXT NOT NULL, '
    '`country_code` TEXT NOT NULL, '
    '`password` TEXT NOT NULL)',
  );
});
final migration5To6 = Migration(5, 6, (database) async {
  await database.execute(
    'CREATE TABLE IF NOT EXISTS `phone_country_codes` ('
    '`id` INTEGER NOT NULL PRIMARY KEY, '
    '`country_code` TEXT NOT NULL, '
    '`country_name` TEXT NOT NULL, '
    '`calling_code` TEXT NOT NULL, '
    '`active` INTEGER NOT NULL)'
  );
});