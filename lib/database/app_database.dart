// ignore_for_file: experimental_member_use

import 'dart:async';

import 'package:floor/floor.dart';
import 'package:machuco/database/migrations/suscripcion/subscription_test_owner_migration.dart';
import 'package:machuco/database/model/motel/motel_entity.dart';
import 'package:machuco/database/model/document_type/document_type_entry.dart';
import 'package:machuco/database/model/notification/notification.dart';
import 'package:machuco/database/model/suscripcion/subscription.dart';
import 'package:machuco/database/repository/auth/auth_catalog_dao.dart';
import 'package:machuco/database/repository/document_type/document_type_repository.dart';
import 'package:machuco/database/repository/motel/motel_dao.dart';
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
  version: 16,
  entities: [
    SubscriptionDetails,
    SubscriptionPayment,
    NotificationEntry,
    NotificationRead,
    PaymentCatalogEntry,
    PaymentRecord,
    ClientEntry,
    PhoneCountryCode,
    MotelEntity,
    OwnerEntry,
    DocumentTypeEntry,
  ],
)
abstract class AppDatabase extends FloorDatabase {
  RoomDao? _roomDao;
  AuthCatalogDao? _authCatalogDao;

  SubscriptionDao get subscriptionDao;
  NotificationDao get notificationDao;
  PaymentDao get paymentDao;
  OwnerDao get ownerDao;
  DocumentTypeDao get documentTypeDao;

  RoomDao get roomDao =>
      _roomDao ??= RoomDao(() async => database as sqflite.Database);

  ClientDao get clientDao;
  PhoneCountryCodeDao get phoneCountryCodeDao;

  AuthCatalogDao get authCatalogDao => _authCatalogDao ??= AuthCatalogDao(
    () async => database as sqflite.Database,
  );
  MotelDao get motelDao;
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
        migration10To11,
        migration11To12,
        migration12To13,
        migration13To14,
        migration14To15,
        migration15To16,
      ])
      .addCallback(
        Callback(
          onCreate: (database, version) async {
            await _createManualSchemas(database, version);
            await _seedDocumentTypes(database);
            await seedSubscriptionTestOwner(database);
          },
        ),
      )
      .build();
}

Future<void> _createManualSchemas(
  sqflite.Database database,
  int version,
) async {
  await _createRoomSchema(database, version);
  await _createAuthCatalogSchema(database);
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

final migration9To10 = Migration(9, 10, (database) async {
  await _createMotelSchema(database);
});

/// Moteles del propietario (caché local).
Future<void> _createMotelSchema(sqflite.DatabaseExecutor database) async {
  await database.execute('''
    CREATE TABLE IF NOT EXISTS motels (
      id TEXT PRIMARY KEY,
      owner_id TEXT NOT NULL,
      name TEXT NOT NULL,
      email TEXT NOT NULL,
      room_count INTEGER NOT NULL,
      nit TEXT NOT NULL,
      address TEXT NOT NULL,
      phone TEXT NOT NULL,
      description TEXT,
      general_location TEXT,
      payment_methods_json TEXT NOT NULL,
      image_urls_json TEXT NOT NULL,
      is_available INTEGER NOT NULL
    )
  ''');
  await database.execute(
    'CREATE UNIQUE INDEX IF NOT EXISTS index_motels_nit ON motels (nit)',
  );
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
    '`country_code` TEXT NOT NULL)',
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

/// Maestros del módulo de autenticación (caché local de Supabase).
Future<void> _createAuthCatalogSchema(sqflite.DatabaseExecutor database) async {
  await database.execute('''
    CREATE TABLE IF NOT EXISTS country_phone_codes (
      id INTEGER PRIMARY KEY,
      iso_code TEXT NOT NULL UNIQUE,
      country_name TEXT NOT NULL,
      dial_code TEXT NOT NULL,
      flag_emoji TEXT,
      phone_min_length INTEGER NOT NULL,
      phone_max_length INTEGER NOT NULL,
      is_active INTEGER NOT NULL CHECK (is_active IN (0, 1)),
      sort_order INTEGER NOT NULL
    )
  ''');
}

/// Ambas ramas publicaron una versión 10 distinta: develop creó `motels` y la
/// rama de autenticación creó `country_phone_codes`. Completa la tabla que
/// falte según de dónde venga la base; todo usa `IF NOT EXISTS`.
final migration10To11 = Migration(10, 11, (database) async {
  await _createAuthCatalogSchema(database);
  await _createMotelSchema(database);
});

final migration11To12 = Migration(11, 12, (database) async {
  final columns = await database.rawQuery("PRAGMA table_info(clients)");
  final hasPasswordColumn = columns.any(
    (column) => column['name'] == 'password',
  );

  if (hasPasswordColumn) {
    await database.execute('ALTER TABLE clients DROP COLUMN password');
  }
});

/// Agrega la tabla de propietarios del módulo de administración de dueños.
///
/// La rama de propietarios publicó esto como 9->10, pero develop reclamó esa
/// versión para `motels`; por eso viaja como 12->13 y usa `IF NOT EXISTS` para
/// ser segura sobre bases que ya la tuvieran.
final migration12To13 = Migration(12, 13, (database) async {
  await _createOwnerSchema(database);
});

Future<void> _createOwnerSchema(sqflite.DatabaseExecutor database) async {
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

/// Separa el indicativo del país del número nacional.
///
/// `owners` se creó en 12->13 con el teléfono concatenado; aquí se agregan las
/// columnas que lo dividen y el nombre del país para mostrarlo sin consultar
/// el maestro. Se consulta `PRAGMA table_info` porque una base nueva ya nace
/// con ambas columnas.
final migration13To14 = Migration(13, 14, (database) async {
  final columns = await database.rawQuery('PRAGMA table_info(owners)');
  final names = columns.map((column) => column['name']).toSet();

  if (!names.contains('countryCode')) {
    await database.execute('ALTER TABLE owners ADD COLUMN countryCode TEXT');
  }
  if (!names.contains('countryName')) {
    await database.execute('ALTER TABLE owners ADD COLUMN countryName TEXT');
  }
});

/// Maestro de tipos de documento que alimenta el selector del formulario.
///
/// Antes vivía solo en el enum `DocumentType`. La tabla permite retirar o
/// reordenar opciones sin recompilar y es la contraparte local de la tabla
/// remota. Las filas usan `code` para mapearse al enum del dominio.
final migration14To15 = Migration(14, 15, (database) async {
  await _createDocumentTypeSchema(database);
  await _seedDocumentTypes(database);
});

/// Borrados diferidos de propietarios.
///
/// Antes, eliminar sin conexión obligaba a conservar el registro. Ahora la fila
/// queda oculta con `pendingDelete = 1` hasta que Firestore confirme el
/// borrado, de modo que la sincronización puede reintentarlo sola.
final migration15To16 = Migration(15, 16, (database) async {
  final columns = await database.rawQuery('PRAGMA table_info(owners)');
  final names = columns.map((column) => column['name']).toSet();
  if (!names.contains('pendingDelete')) {
    await database.execute(
      'ALTER TABLE owners ADD COLUMN pendingDelete INTEGER NOT NULL '
      'DEFAULT 0',
    );
  }
});

Future<void> _createDocumentTypeSchema(
  sqflite.DatabaseExecutor database,
) async {
  await database.execute('''
    CREATE TABLE IF NOT EXISTS document_types (
      id INTEGER NOT NULL PRIMARY KEY,
      code TEXT NOT NULL,
      name TEXT NOT NULL,
      pattern TEXT NOT NULL,
      example TEXT NOT NULL,
      isActive INTEGER NOT NULL,
      sortOrder INTEGER NOT NULL
    )
  ''');
}

/// Semillas del maestro; `INSERT OR IGNORE` permite correrla también en bases
/// nuevas, donde Floor ya creó la tabla vacía.
Future<void> _seedDocumentTypes(sqflite.DatabaseExecutor database) async {
  const rows = [
    {
      'id': 1,
      'code': 'CC',
      'name': 'Cédula de ciudadanía',
      'pattern': r'^\d{6,10}$',
      'example': '1020304050',
      'isActive': 1,
      'sortOrder': 1,
    },
    {
      'id': 2,
      'code': 'CE',
      'name': 'Cédula de extranjería',
      'pattern': r'^\d{6,12}$',
      'example': '345678',
      'isActive': 1,
      'sortOrder': 2,
    },
    {
      'id': 3,
      'code': 'NIT',
      'name': 'Número de identificación tributaria',
      'pattern': r'^\d{9,10}(-\d)?$',
      'example': '900123456-7',
      'isActive': 1,
      'sortOrder': 3,
    },
    {
      'id': 4,
      'code': 'PAS',
      'name': 'Pasaporte',
      'pattern': r'^[A-Za-z0-9]{6,12}$',
      'example': 'AV123456',
      'isActive': 1,
      'sortOrder': 4,
    },
    {
      'id': 5,
      'code': 'TI',
      'name': 'Tarjeta de identidad',
      'pattern': r'^\d{6,11}$',
      'example': '1020304050',
      'isActive': 1,
      'sortOrder': 5,
    },
  ];

  for (final row in rows) {
    await database.insert(
      'document_types',
      row,
      conflictAlgorithm: sqflite.ConflictAlgorithm.ignore,
    );
  }
}
