// ignore_for_file: experimental_member_use

import 'dart:async';

import 'package:floor/floor.dart';
import 'package:machuco/database/migrations/suscripcion/subscription_test_owner_migration.dart';
import 'package:machuco/database/model/notification/notification.dart';
import 'package:machuco/database/model/suscripcion/subscription.dart';
import 'package:machuco/database/repository/notification/notification_repository.dart';
import 'package:machuco/database/model/client/client.dart';
import 'package:machuco/database/repository/client/client_repository.dart';
import 'package:machuco/database/repository/room/room_dao.dart';
import 'package:machuco/database/repository/suscripcion/subscription_repository.dart';
import 'package:machuco/models/payment/payment.dart';
import 'package:machuco/models/payment/payment_catalog_entry.dart';
import 'package:machuco/repositories/payment/payment_dao.dart';
import 'package:machuco/database/model/phone_country_code/phone_country_code.dart';
import 'package:machuco/database/repository/phone_country_code/phone_country_code_repository.dart';
import 'package:machuco/database/model/owner/owner_entry.dart';
import 'package:machuco/database/repository/owner/owner_repository.dart';
import 'package:sqflite/sqflite.dart' as sqflite;

part 'app_database.g.dart';

@TypeConverters([
  SubscriptionDateConverter,
  SubscriptionStatusConverter,
  SubscriptionFeaturesConverter,
  PaymentStatusConverter,
  PaymentMethodConverter,
  PaymentOptionalDateConverter,
])
@Database(
  version: 10,
  entities: [
    SubscriptionDetails,
    SubscriptionPayment,
    NotificationEntry,
    NotificationRead,
    PaymentCatalogEntry,
    PaymentRecord,
    ClientEntry,
    PhoneCountryCode,
    OwnerEntry,
  ],
)
abstract class AppDatabase extends FloorDatabase {
  RoomDao? _roomDao;

  SubscriptionDao get subscriptionDao;
  NotificationDao get notificationDao;
  PaymentDao get paymentDao;
  OwnerDao get ownerDao;

  RoomDao get roomDao =>
      _roomDao ??= RoomDao(() async => database as sqflite.Database);

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
  }) => $FloorAppDatabase
      .databaseBuilder(name)
      .addMigrations([
        migration1To2,
        migration2To3,
        migration3To4,
        migration4To5,
        migration5To6,
        migration6To7,
        migration7To8,
        migration8To9,
        migration9To10,
      ])
      .addCallback(
        Callback(
          onCreate: (database, version) async {
            await _createRoomSchema(database, version);
            await seedSubscriptionTestOwner(database);
          },
        ),
      )
      .build();
}

Future<void> _createRoomSchema(sqflite.Database database, int _) async {
  await database.execute('''
    CREATE TABLE IF NOT EXISTS room_types (
      id TEXT PRIMARY KEY,
      motel_id TEXT NOT NULL,
      name TEXT NOT NULL
    )
  ''');
  await database.execute('''
    CREATE UNIQUE INDEX IF NOT EXISTS room_types_motel_name
    ON room_types(motel_id, name COLLATE NOCASE)
  ''');
  await database.execute('''
    CREATE TABLE IF NOT EXISTS rooms (
      id TEXT PRIMARY KEY,
      motel_id TEXT NOT NULL,
      name TEXT NOT NULL,
      description TEXT NOT NULL,
      type_id TEXT NOT NULL,
      price_per_hour INTEGER NOT NULL,
      room_number TEXT NOT NULL,
      capacity INTEGER NOT NULL,
      image_urls_json TEXT NOT NULL,
      is_active INTEGER NOT NULL CHECK (is_active IN (0, 1)),
      included_services_json TEXT NOT NULL,
      FOREIGN KEY (type_id) REFERENCES room_types(id)
        ON UPDATE CASCADE ON DELETE RESTRICT
    )
  ''');
  await database.execute('''
    CREATE UNIQUE INDEX IF NOT EXISTS rooms_motel_number
    ON rooms(motel_id, room_number COLLATE NOCASE)
  ''');
  await database.execute('''
    CREATE TABLE IF NOT EXISTS room_included_services (
      id INTEGER PRIMARY KEY,
      name TEXT NOT NULL UNIQUE
    )
  ''');
}

/// La migración 4 a 5 pertenece al módulo de habitaciones.
final migration4To5 = Migration(
  4,
  5,
  (database) => _createRoomSchema(database, 5),
);

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

/// Agrega notificaciones y normaliza el esquema de habitaciones tras la
/// colisión histórica de la versión 5 entre ambos módulos.
final migration5To6 = Migration(5, 6, (database) async {
  await _createRoomSchema(database, 6);
  await database.execute(
    'CREATE TABLE IF NOT EXISTS notifications ('
    'id INTEGER PRIMARY KEY AUTOINCREMENT, typeId INTEGER NOT NULL, '
    'title TEXT NOT NULL, message TEXT NOT NULL, sentAt INTEGER NOT NULL, '
    'target TEXT NOT NULL, recipientUser TEXT)',
  );
  await database.execute(
    'CREATE TABLE IF NOT EXISTS notification_reads ('
    'id INTEGER PRIMARY KEY AUTOINCREMENT, notificationId INTEGER NOT NULL, '
    'userId TEXT NOT NULL, readAt INTEGER NOT NULL, '
    'FOREIGN KEY (notificationId) REFERENCES notifications (id))',
  );
  await database.execute(
    'CREATE UNIQUE INDEX IF NOT EXISTS index_notification_reads_notificationId_userId '
    'ON notification_reads (notificationId, userId)',
  );
});

/// Agrega los esquemas de Payment y clientes sin modificar tablas existentes.
final migration6To7 = Migration(6, 7, (database) async {
  await _createPaymentSchema(database);
  await _createClientSchema(database);
});

/// Ambas ramas publicaron una versión 7 con tablas distintas. Completa las
/// tablas faltantes sin borrar los pagos, clientes ni catálogos existentes.
final migration7To8 = Migration(7, 8, (database) async {
  await _createPaymentSchema(database);
  await _createClientSchema(database);
});

/// Actualiza bases existentes para dejar disponible la suscripciÃ³n de prueba.
final migration8To9 = Migration(8, 9, (database) async {
  await seedSubscriptionTestOwner(database);
});

/// Agrega la tabla de propietarios del módulo de administración de dueños.
///
/// Debe coincidir con el esquema que genera Floor para `OwnerEntry`.
final migration9To10 = Migration(9, 10, (database) async {
  await _createOwnerSchema(database);
});

Future<void> _createOwnerSchema(sqflite.Database database) async {
  await database.execute('''
    CREATE TABLE IF NOT EXISTS owners (
      id TEXT NOT NULL PRIMARY KEY,
      fullName TEXT NOT NULL,
      documentType TEXT NOT NULL,
      documentNumber TEXT NOT NULL,
      email TEXT NOT NULL,
      phone TEXT NOT NULL,
      address TEXT,
      isActive INTEGER NOT NULL,
      synchronized INTEGER NOT NULL,
      createdAt INTEGER NOT NULL,
      updatedAt INTEGER NOT NULL
    )
  ''');
}

Future<void> _createPaymentSchema(sqflite.Database database) async {
  await database.execute(
    'CREATE TABLE IF NOT EXISTS payment_method_catalog ('
    'id INTEGER NOT NULL PRIMARY KEY, name TEXT NOT NULL)',
  );
  await database.execute(
    'CREATE TABLE IF NOT EXISTS payments ('
    'id TEXT NOT NULL PRIMARY KEY, bookingId TEXT NOT NULL, '
    'bookingReference TEXT NOT NULL, clientId TEXT NOT NULL, '
    'client TEXT NOT NULL, motelId TEXT NOT NULL, motel TEXT NOT NULL, '
    'roomId TEXT NOT NULL, room TEXT NOT NULL, '
    'reservationDate INTEGER NOT NULL, amount INTEGER NOT NULL, '
    'status TEXT NOT NULL, method TEXT, paymentMethodId INTEGER, '
    'paidAt INTEGER, receiptNumber TEXT, '
    'FOREIGN KEY (paymentMethodId) REFERENCES payment_method_catalog (id))',
  );
  for (final column in ['clientId', 'motelId', 'paymentMethodId']) {
    await database.execute(
      'CREATE INDEX IF NOT EXISTS index_payments_$column ON payments ($column)',
    );
  }
}

Future<void> _createClientSchema(sqflite.Database database) async {
  await database.execute(
    'CREATE TABLE IF NOT EXISTS `clients` ('
    '`id` INTEGER PRIMARY KEY AUTOINCREMENT, '
    '`name` TEXT NOT NULL, '
    '`phone` TEXT NOT NULL, '
    '`email` TEXT NOT NULL, '
    '`country_code` TEXT NOT NULL, '
    '`password` TEXT NOT NULL)',
  );
  await database.execute(
    'CREATE TABLE IF NOT EXISTS `phone_country_codes` ('
    '`id` INTEGER NOT NULL PRIMARY KEY, '
    '`country_code` TEXT NOT NULL, '
    '`country_name` TEXT NOT NULL, '
    '`calling_code` TEXT NOT NULL, '
    '`active` INTEGER NOT NULL)',
  );
}
