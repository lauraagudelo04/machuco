import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:machuco/database/app_database.dart';
import 'package:machuco/database/model/client/client.dart';
import 'package:machuco/database/model/phone_country_code/phone_country_code.dart';
import 'package:machuco/models/payment/payment.dart';
import 'package:machuco/models/payment/payment_catalog_entry.dart';
import 'package:sqflite/sqflite.dart' as sqflite;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const catalog = [
    PaymentCatalogEntry(id: 1, name: 'Efectivo'),
    PaymentCatalogEntry(id: 2, name: 'Tarjeta de crédito'),
    PaymentCatalogEntry(id: 3, name: 'Tarjeta de débito'),
    PaymentCatalogEntry(id: 4, name: 'Transferencia bancaria'),
  ];

  late Directory directory;
  late String path;
  late AppDatabase database;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('machuco_payment_');
    path = '${directory.path}${Platform.pathSeparator}payments.db';
    database = await AppDatabaseProvider.open(name: path);
  });

  tearDown(() async {
    await database.close();
    await directory.delete(recursive: true);
  });

  PaymentRecord payment({
    String id = 'pay-001',
    String clientId = 'client-1',
    String motelId = 'motel-1',
    PaymentStatus status = PaymentStatus.pending,
    PaymentMethod? legacyMethod,
    int? methodId,
    DateTime? paidAt,
    String? receiptNumber,
  }) => PaymentRecord(
    id: id,
    bookingId: 'booking-$id',
    bookingReference: 'RES-$id',
    clientId: clientId,
    client: 'Cliente de prueba',
    motelId: motelId,
    motel: 'Motel de prueba',
    roomId: 'room-1',
    room: 'Habitación 1',
    reservationDate: DateTime(2026, 10, 16, 20, 30, 0, 0, 123),
    amount: 120000,
    status: status,
    method: legacyMethod,
    paymentMethodId: methodId,
    paidAt: paidAt,
    receiptNumber: receiptNumber,
  );

  test('mapea nombre del maestro y rechaza datos inválidos', () {
    final entry = PaymentCatalogEntry.fromJson({
      'id': 2,
      'nombre': ' Tarjeta de crédito ',
    });
    expect(entry.id, 2);
    expect(entry.name, 'Tarjeta de crédito');

    for (final row in <Map<String, dynamic>>[
      {'id': '1', 'nombre': 'Efectivo'},
      {'id': 0, 'nombre': 'Efectivo'},
      {'id': 1, 'nombre': ' '},
      {'id': 1, 'name': 'Efectivo'},
      {'id': 1, 'nombre': null},
    ]) {
      expect(() => PaymentCatalogEntry.fromJson(row), throwsFormatException);
    }
  });

  test('conserva pagos, fechas y maestro al cerrar y reabrir SQLite', () async {
    await database.paymentDao.saveCatalogEntries(catalog);
    final paidAt = DateTime(2026, 10, 16, 21, 0, 0, 0, 456);
    final saved = payment(
      status: PaymentStatus.paid,
      methodId: 4,
      paidAt: paidAt,
      receiptNumber: 'LOCAL-001',
    );
    await database.paymentDao.insertPayment(saved);
    await database.close();
    database = await AppDatabaseProvider.open(name: path);

    final restored = (await database.paymentDao.findById(saved.id))!;
    expect(restored.bookingId, saved.bookingId);
    expect(restored.bookingReference, saved.bookingReference);
    expect(restored.clientId, saved.clientId);
    expect(restored.client, saved.client);
    expect(restored.motelId, saved.motelId);
    expect(restored.motel, saved.motel);
    expect(restored.roomId, saved.roomId);
    expect(restored.room, saved.room);
    expect(restored.reservationDate, saved.reservationDate);
    expect(restored.amount, 120000);
    expect(restored.status, PaymentStatus.paid);
    expect(restored.paymentMethodId, 4);
    expect(restored.method, isNull);
    expect(restored.paidAt, paidAt);
    expect(restored.receiptNumber, 'LOCAL-001');
    expect(await database.paymentDao.findCatalogEntries(), hasLength(4));
  });

  test('filtra por cliente y motel sin mezclar registros', () async {
    await database.paymentDao.insertPayment(payment(id: 'pay-1'));
    await database.paymentDao.insertPayment(
      payment(id: 'pay-2', clientId: 'client-2'),
    );
    await database.paymentDao.insertPayment(
      payment(id: 'pay-3', motelId: 'motel-2'),
    );

    expect(
      (await database.paymentDao.findByClient('client-1')).map((row) => row.id),
      ['pay-3', 'pay-1'],
    );
    expect(
      (await database.paymentDao.findByMotel('motel-1')).map((row) => row.id),
      ['pay-2', 'pay-1'],
    );
    expect(await database.paymentDao.findByClient('missing'), isEmpty);
    expect(await database.paymentDao.findByMotel('missing'), isEmpty);
    expect(await database.paymentDao.findById('missing'), isNull);
    expect(await database.paymentDao.findAll(), hasLength(3));
  });

  test(
    'conserva los estados y no inventa un método para pagos online',
    () async {
      for (final status in PaymentStatus.values) {
        await database.paymentDao.insertPayment(
          payment(
            id: status.name,
            status: status,
            legacyMethod: status == PaymentStatus.paid
                ? PaymentMethod.online
                : null,
          ),
        );
        final restored = (await database.paymentDao.findById(status.name))!;
        expect(restored.status, status);
        expect(restored.paymentMethodId, isNull);
        expect(restored.paidAt, isNull);
      }
      final online = (await database.paymentDao.findById('paid'))!;
      expect(online.method, PaymentMethod.online);
    },
  );

  for (final method in catalog) {
    test('registra pago en el local con ${method.name}', () async {
      await database.paymentDao.saveCatalogEntries(catalog);
      await database.paymentDao.insertPayment(payment());
      final paidAt = DateTime(2026, 10, 16, 21);

      expect(
        await database.paymentDao.registerLocalPayment(
          'pay-001',
          'motel-1',
          method.id,
          paidAt,
          'LOCAL-001',
        ),
        1,
      );
      final restored = (await database.paymentDao.findById('pay-001'))!;
      expect(restored.status, PaymentStatus.paid);
      expect(restored.paymentMethodId, method.id);
      expect(restored.method, isNull);
      expect(restored.paidAt, paidAt);
      expect(restored.receiptNumber, 'LOCAL-001');
    });
  }

  test(
    'no confirma un pago de otro motel ni con un método desconocido',
    () async {
      await database.paymentDao.saveCatalogEntries(catalog);
      await database.paymentDao.insertPayment(payment());

      for (final attempt in [
        ('pay-001', 'other-motel', 1),
        ('pay-001', 'motel-1', 99),
        ('missing', 'motel-1', 1),
      ]) {
        expect(
          await database.paymentDao.registerLocalPayment(
            attempt.$1,
            attempt.$2,
            attempt.$3,
            DateTime.now(),
            'INVALID',
          ),
          0,
        );
      }
      final unchanged = (await database.paymentDao.findById('pay-001'))!;
      expect(unchanged.status, PaymentStatus.pending);
      expect(unchanged.paymentMethodId, isNull);
      expect(unchanged.receiptNumber, isNull);
    },
  );

  test('dos confirmaciones simultáneas solo registran un pago', () async {
    await database.paymentDao.saveCatalogEntries(catalog);
    await database.paymentDao.insertPayment(payment());
    final results = await Future.wait([
      database.paymentDao.registerLocalPayment(
        'pay-001',
        'motel-1',
        1,
        DateTime(2026, 10, 16),
        'FIRST',
      ),
      database.paymentDao.registerLocalPayment(
        'pay-001',
        'motel-1',
        2,
        DateTime(2026, 10, 17),
        'SECOND',
      ),
    ]);
    expect(results.where((value) => value == 1), hasLength(1));
    expect(results.where((value) => value == 0), hasLength(1));
    final saved = (await database.paymentDao.findById('pay-001'))!;
    final winningIndex = results.indexOf(1);
    expect(saved.paymentMethodId, winningIndex + 1);
    expect(saved.receiptNumber, winningIndex == 0 ? 'FIRST' : 'SECOND');
    expect(
      await database.paymentDao.registerLocalPayment(
        'pay-001',
        'motel-1',
        4,
        DateTime.now(),
        'DUPLICATE',
      ),
      0,
    );
    expect(
      (await database.paymentDao.findById('pay-001'))!.receiptNumber,
      saved.receiptNumber,
    );
  });

  test('no permite confirmar pagos cancelados o reembolsados', () async {
    await database.paymentDao.saveCatalogEntries(catalog);
    for (final status in [PaymentStatus.cancelled, PaymentStatus.refunded]) {
      await database.paymentDao.insertPayment(
        payment(id: status.name, status: status),
      );
      expect(
        await database.paymentDao.registerLocalPayment(
          status.name,
          'motel-1',
          1,
          DateTime.now(),
          'INVALID',
        ),
        0,
      );
      expect((await database.paymentDao.findById(status.name))!.status, status);
    }
  });

  test('actualiza el maestro sin borrar métodos vinculados a pagos', () async {
    await database.paymentDao.saveCatalogEntries(catalog);
    await database.paymentDao.insertPayment(
      payment(status: PaymentStatus.paid, methodId: 1),
    );
    await database.paymentDao.saveCatalogEntries([
      const PaymentCatalogEntry(id: 1, name: 'Efectivo actualizado'),
      const PaymentCatalogEntry(id: 5, name: 'Nuevo método'),
    ]);

    final entries = await database.paymentDao.findCatalogEntries();
    expect(entries.map((entry) => entry.id), [1, 2, 3, 4, 5]);
    expect(entries.first.name, 'Efectivo actualizado');
    expect((await database.paymentDao.findById('pay-001'))!.paymentMethodId, 1);
  });

  test('rechaza IDs duplicados y referencias a métodos inexistentes', () async {
    await database.paymentDao.insertPayment(payment());
    await expectLater(
      database.paymentDao.insertPayment(payment()),
      throwsA(isA<sqflite.DatabaseException>()),
    );
    await expectLater(
      database.paymentDao.insertPayment(payment(id: 'invalid', methodId: 99)),
      throwsA(isA<sqflite.DatabaseException>()),
    );
    expect(await database.paymentDao.findAll(), hasLength(1));
  });

  for (final hasPayments in [true, false]) {
    test(
      'migra v7 de ${hasPayments ? 'Payment' : 'clientes'} a v11 sin perder datos',
      () async {
        var raw = database.database as sqflite.Database;
        final freshSchema = await _moduleSchema(raw);
        if (hasPayments) {
          await database.paymentDao.saveCatalogEntries(catalog);
          await database.paymentDao.insertPayment(
            payment(status: PaymentStatus.paid, methodId: 1),
          );
          await raw.execute('DROP TABLE clients');
          await raw.execute('DROP TABLE phone_country_codes');
        } else {
          await database.clientDao.insertClient(
            ClientEntry(
              id: 1,
              name: 'Cliente existente',
              phone: '3001234567',
              email: 'client@example.com',
              countryCode: 'CO',
              password: 'fixture-only',
            ),
          );
          await database.phoneCountryCodeDao.insertCountryCodes([
            const PhoneCountryCode(
              id: 1,
              countryCode: 'CO',
              countryName: 'Colombia',
              callingCode: '+57',
              active: true,
            ),
          ]);
          await raw.execute('DROP TABLE payments');
          await raw.execute('DROP TABLE payment_method_catalog');
        }
        await raw.setVersion(7);
        final tables = await raw.rawQuery(
          "SELECT name FROM sqlite_master WHERE type = 'table' "
          "AND name NOT LIKE 'sqlite_%' ORDER BY name",
        );
        final previousData = <String, List<Map<String, Object?>>>{};
        for (final table in tables) {
          final name = table['name'] as String;
          previousData[name] = await raw.query(name);
        }

        await database.close();
        database = await AppDatabaseProvider.open(name: path);
        raw = database.database as sqflite.Database;

        expect(await raw.getVersion(), 11);
        expect(await _moduleSchema(raw), freshSchema);
        for (final entry in previousData.entries) {
          expect(await raw.query(entry.key), entry.value, reason: entry.key);
        }
        expect(await raw.rawQuery('PRAGMA foreign_key_check'), isEmpty);
        expect(
          await database.paymentDao.findAll(),
          hasLength(hasPayments ? 1 : 0),
        );
        expect(
          await database.clientDao.findAll(),
          hasLength(hasPayments ? 0 : 1),
        );
        expect(
          await database.phoneCountryCodeDao.findActive(),
          hasLength(hasPayments ? 0 : 1),
        );
      },
    );
  }

  test('migra de v6 a v11 conservando los otros módulos y el esquema', () async {
    var raw = database.database as sqflite.Database;
    final freshSchema = await _moduleSchema(raw);

    // Fixture aislada: el esquema v6 no incluye tablas de Payment ni clientes.
    // Ninguna base de la aplicación se borra ni se degrada durante la migración.
    await raw.execute('DROP TABLE payments');
    await raw.execute('DROP TABLE payment_method_catalog');
    await raw.execute('DROP TABLE clients');
    await raw.execute('DROP TABLE phone_country_codes');
    await raw.setVersion(6);
    // La base nueva trae la suscripciÃ³n de prueba; se limpia para construir
    // un fixture v6 con una suscripciÃ³n existente de id conocido.
    await raw.delete('subscription_payments');
    await raw.delete('subscriptions');
    await raw.delete(
      'sqlite_sequence',
      where: 'name IN (?, ?)',
      whereArgs: ['subscriptions', 'subscription_payments'],
    );
    await raw.insert('subscriptions', {
      'id': 1,
      'userEmail': 'owner@example.com',
      'planId': 1,
      'planName': 'Plan existente',
      'motelName': 'Motel existente',
      'amount': 100000,
      'billingPeriod': 'Mensual',
      'nextBillingDate': 1,
      'status': 'active',
      'features': '[]',
    });
    await raw.insert('subscription_payments', {
      'id': 1,
      'subscriptionId': 1,
      'date': 1,
      'amount': 100000,
      'paymentMethod': 'Efectivo',
      'reference': 'OLD',
      'status': 'active',
    });
    await raw.insert('notifications', {
      'id': 1,
      'typeId': 1,
      'title': 'Aviso existente',
      'message': 'Mensaje',
      'sentAt': 1,
      'target': 'all',
    });
    await raw.insert('notification_reads', {
      'id': 1,
      'notificationId': 1,
      'userId': 'client-1',
      'readAt': 1,
    });
    await raw.insert('room_types', {
      'id': 'type-1',
      'motel_id': 'motel-1',
      'name': 'Suite',
    });
    await raw.insert('rooms', {
      'id': 'room-1',
      'motel_id': 'motel-1',
      'name': 'Suite 1',
      'description': 'Habitación existente',
      'type_id': 'type-1',
      'price_per_hour': 50000,
      'room_number': '1',
      'capacity': 2,
      'image_urls_json': '[]',
      'is_active': 1,
      'included_services_json': '[]',
    });
    await raw.insert('room_included_services', {'id': 1, 'name': 'Jacuzzi'});

    final previousSchema = await raw.rawQuery(
      "SELECT name, sql FROM sqlite_master WHERE type = 'table' "
      "AND name NOT LIKE 'sqlite_%' ORDER BY name",
    );
    final previousData = <String, List<Map<String, Object?>>>{};
    for (final table in previousSchema) {
      final name = table['name'] as String;
      previousData[name] = await raw.query(name);
    }
    await database.close();
    database = await AppDatabaseProvider.open(name: path);
    raw = database.database as sqflite.Database;

    expect(await raw.getVersion(), 11);
    expect(await _moduleSchema(raw), freshSchema);
    for (final table in previousSchema) {
      final name = table['name'] as String;
      final migratedRows = await raw.query(name);
      if (name == 'subscriptions') {
        // La migraciÃ³n 8->9 puede agregar la suscripciÃ³n de prueba, pero
        // nunca debe eliminar la suscripciÃ³n que ya existÃ­a.
        for (final previousRow in previousData[name]!) {
          expect(migratedRows, contains(equals(previousRow)), reason: name);
        }
      } else {
        expect(migratedRows, previousData[name], reason: name);
      }
      expect(
        await raw.rawQuery('SELECT sql FROM sqlite_master WHERE name = ?', [
          name,
        ]),
        [
          {'sql': table['sql']},
        ],
        reason: 'El esquema de $name no debe cambiar',
      );
    }
    await database.paymentDao.saveCatalogEntries(catalog);
    await database.paymentDao.insertPayment(payment());
    expect(
      await database.paymentDao.registerLocalPayment(
        'pay-001',
        'motel-1',
        3,
        DateTime.now(),
        'AFTER-MIGRATION',
      ),
      1,
    );
  });

  test('una v10 de la rama de autenticación recibe la tabla motels', () async {
    var raw = database.database as sqflite.Database;
    final motelsColumns = await _columnNames(raw, 'motels');

    // La rama de autenticación publicó una v10 con country_phone_codes y sin
    // motels; la migración 10 a 11 debe completar la tabla que falta.
    await raw.execute('DROP TABLE motels');
    await raw.insert('country_phone_codes', {
      'id': 1,
      'iso_code': 'CO',
      'country_name': 'Colombia',
      'dial_code': '+57',
      'phone_min_length': 10,
      'phone_max_length': 10,
      'is_active': 1,
      'sort_order': 1,
    });
    await raw.setVersion(10);
    await database.close();
    database = await AppDatabaseProvider.open(name: path);
    raw = database.database as sqflite.Database;

    expect(await raw.getVersion(), 11);
    expect(await _columnNames(raw, 'motels'), motelsColumns);
    expect(await raw.query('country_phone_codes'), hasLength(1));
  });
}

Future<Map<String, List<Map<String, Object?>>>> _moduleSchema(
  sqflite.Database database,
) async {
  final schema = <String, List<Map<String, Object?>>>{};
  for (final table in [
    'payment_method_catalog',
    'payments',
    'clients',
    'phone_country_codes',
  ]) {
    for (final pragma in ['table_info', 'foreign_key_list', 'index_list']) {
      schema['$table.$pragma'] = await database.rawQuery(
        'PRAGMA $pragma($table)',
      );
    }
  }
  return schema;
}

Future<List<String>> _columnNames(
  sqflite.Database database,
  String table,
) async {
  final columns = await database.rawQuery('PRAGMA table_info($table)');
  return [for (final column in columns) column['name']! as String];
}
