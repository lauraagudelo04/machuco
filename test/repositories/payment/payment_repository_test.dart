import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:machuco/database/app_database.dart';
import 'package:machuco/models/payment/payment.dart';
import 'package:machuco/models/payment/payment_catalog_entry.dart';
import 'package:machuco/repositories/payment/payment_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final catalogRows = [
    {'id': 1, 'nombre': 'Efectivo'},
    {'id': 2, 'nombre': 'Tarjeta de crédito'},
    {'id': 3, 'nombre': 'Tarjeta de débito'},
    {'id': 4, 'nombre': 'Transferencia bancaria'},
  ];
  final paidAt = DateTime(2026, 10, 16, 21, 30);
  final clients = <http.Client>[];
  late Directory directory;
  late String path;
  late AppDatabase database;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('machuco_payment_repo_');
    path = '${directory.path}${Platform.pathSeparator}payments.db';
    database = await AppDatabaseProvider.open(name: path);
  });

  tearDown(() async {
    for (final client in clients) {
      client.close();
    }
    clients.clear();
    await database.close();
    await directory.delete(recursive: true);
  });

  PaymentRepository repository({
    Future<http.Response> Function(http.Request)? respond,
    String url = 'https://example.supabase.co',
    String key = 'publishable-test-key',
    Duration timeout = const Duration(seconds: 15),
  }) {
    final client = MockClient(
      respond ??
          (_) async =>
              http.Response.bytes(utf8.encode(jsonEncode(catalogRows)), 200),
    );
    clients.add(client);
    return PaymentRepository(
      database: database,
      client: client,
      supabaseUrl: url,
      publishableKey: key,
      requestTimeout: timeout,
      now: () => paidAt,
    );
  }

  PaymentRecord payment({
    String id = 'pay-1',
    String clientId = 'client-1',
    String motelId = 'motel-1',
    int amount = 120000,
    PaymentStatus status = PaymentStatus.pending,
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
    reservationDate: DateTime(2026, 10, 16),
    amount: amount,
    status: status,
  );

  TypeMatcher<PaymentRepositoryException> repositoryError(
    PaymentRepositoryError kind,
  ) => isA<PaymentRepositoryException>().having(
    (error) => error.kind,
    'kind',
    kind,
  );

  test(
    'envía el contrato HTTP y guarda nombres con acentos en SQLite',
    () async {
      final repo = repository(
        url: 'https://example.supabase.co/',
        respond: (request) async {
          expect(request.method, 'GET');
          expect(request.url.path, '/rest/v1/payment_method');
          expect(request.url.queryParameters, {
            'select': 'id,nombre',
            'order': 'id.asc',
          });
          expect(request.headers['apikey'], 'publishable-test-key');
          expect(request.headers['Accept'], 'application/json');
          expect(request.headers.containsKey('Authorization'), isFalse);
          expect(request.body, isEmpty);
          // Sin charset explícito: el repositorio debe decodificar bodyBytes.
          return http.Response.bytes(
            utf8.encode(jsonEncode(catalogRows.reversed.toList())),
            200,
          );
        },
      );

      final methods = await repo.findPaymentMethods();
      expect(methods.map((entry) => entry.id), [1, 2, 3, 4]);
      expect(methods[1].name, 'Tarjeta de crédito');
      expect(methods[2].name, 'Tarjeta de débito');
      expect(
        (await database.paymentDao.findCatalogEntries()).map(
          (entry) => entry.name,
        ),
        methods.map((entry) => entry.name),
      );
    },
  );

  test('recupera el maestro después de reabrir y perder la conexión', () async {
    await repository().findPaymentMethods();
    await database.close();
    database = await AppDatabaseProvider.open(name: path);
    final offline = repository(
      respond: (_) async => throw http.ClientException('Sin conexión'),
    );

    final methods = await offline.findPaymentMethods();
    expect(methods.map((entry) => entry.id), [1, 2, 3, 4]);
    expect(methods[1].name, 'Tarjeta de crédito');
  });

  test('actualiza nombres del maestro sin perder pagos vinculados', () async {
    final repo = repository();
    await repo.findPaymentMethods();
    await repo.createPayment(payment());
    await repo.registerLocalPayment(
      paymentId: 'pay-1',
      motelId: 'motel-1',
      paymentMethodId: 1,
    );
    final refreshed = await repository(
      respond: (_) async =>
          http.Response('[{"id":1,"nombre":"Efectivo actualizado"}]', 200),
    ).findPaymentMethods();

    expect(refreshed.single.name, 'Efectivo actualizado');
    expect((await repo.findPayment('pay-1'))!.paymentMethodId, 1);
    expect(
      (await database.paymentDao.findCatalogEntries()).first.name,
      'Efectivo actualizado',
    );
  });

  for (final status in [401, 403, 429, 500, 503]) {
    test(
      'maneja HTTP $status sin exponer el cuerpo y recupera caché',
      () async {
        final repo = repository(
          respond: (_) async =>
              http.Response('sensitive-server-detail', status),
        );
        await expectLater(
          repo.findPaymentMethods(),
          throwsA(
            repositoryError(PaymentRepositoryError.remote).having(
              (error) => error.toString(),
              'message',
              isNot(contains('sensitive-server-detail')),
            ),
          ),
        );
        await database.paymentDao.saveCatalogEntries([
          const PaymentCatalogEntry(id: 1, name: 'Efectivo guardado'),
        ]);
        expect(
          (await repo.findPaymentMethods()).single.name,
          'Efectivo guardado',
        );
      },
    );
  }

  final invalidBodies = [
    'no-json',
    '{}',
    'null',
    '[]',
    '[1]',
    '[{"id":"1","nombre":"Efectivo"}]',
    '[{"id":0,"nombre":"Efectivo"}]',
    '[{"id":1,"nombre":" "}]',
    '[{"id":1,"name":"Efectivo"}]',
    '[{"id":1,"nombre":"Efectivo"},{"id":1,"nombre":"Otro"}]',
    '[{"id":2,"nombre":"Válido"},{"id":3,"nombre":null}]',
  ];
  for (var index = 0; index < invalidBodies.length; index++) {
    test(
      'rechaza respuesta inválida $index sin modificar la copia local',
      () async {
        final repo = repository(
          respond: (_) async =>
              http.Response.bytes(utf8.encode(invalidBodies[index]), 200),
        );
        await expectLater(
          repo.findPaymentMethods(),
          throwsA(repositoryError(PaymentRepositoryError.invalidCatalog)),
        );
        await database.paymentDao.saveCatalogEntries([
          const PaymentCatalogEntry(id: 1, name: 'Copia válida'),
        ]);
        final cached = await repo.findPaymentMethods();
        expect(cached.single.name, 'Copia válida');
        expect((await database.paymentDao.findCatalogEntries()).single.id, 1);
      },
    );
  }

  test('controla errores de red sin copia disponible', () async {
    final repo = repository(
      respond: (_) async => throw http.ClientException('Detalle de red'),
    );
    await expectLater(
      repo.findPaymentMethods(),
      throwsA(repositoryError(PaymentRepositoryError.connection)),
    );
  });

  test('limita la espera y usa caché cuando hay timeout', () async {
    final repo = repository(
      timeout: const Duration(milliseconds: 5),
      respond: (_) => Completer<http.Response>().future,
    );
    await expectLater(
      repo.findPaymentMethods(),
      throwsA(repositoryError(PaymentRepositoryError.connection)),
    );
    await database.paymentDao.saveCatalogEntries([
      const PaymentCatalogEntry(id: 1, name: 'Efectivo guardado'),
    ]);
    expect((await repo.findPaymentMethods()).single.id, 1);
  });

  test('rechaza configuración inválida sin enviar peticiones HTTP', () async {
    for (final config in [
      ('', 'key'),
      ('not-a-url', 'key'),
      ('http://example.supabase.co', 'key'),
      ('https://user:password@example.supabase.co', 'key'),
      ('https://example.supabase.co?apikey=key', 'key'),
      ('https://example.supabase.co#fragment', 'key'),
      ('https://example.supabase.co', ' '),
    ]) {
      var requests = 0;
      final repo = repository(
        url: config.$1,
        key: config.$2,
        respond: (_) async {
          requests++;
          return http.Response('[]', 200);
        },
      );
      await expectLater(
        repo.findPaymentMethods(),
        throwsA(repositoryError(PaymentRepositoryError.configuration)),
      );
      expect(requests, 0);
    }
  });

  test('permite leer caché si no hay configuración remota', () async {
    await database.paymentDao.saveCatalogEntries([
      const PaymentCatalogEntry(id: 1, name: 'Efectivo'),
    ]);
    expect(
      (await repository(url: '', key: '').findPaymentMethods()).single.id,
      1,
    );
  });

  test('no oculta fallos de SQLite como errores de red', () async {
    final repo = repository();
    await database.close();
    await expectLater(
      repo.findPaymentMethods(),
      throwsA(repositoryError(PaymentRepositoryError.storage)),
    );
    await expectLater(
      repo.findAllPayments(),
      throwsA(repositoryError(PaymentRepositoryError.storage)),
    );
  });

  test('crea pagos y consulta por cliente y motel sin llamadas HTTP', () async {
    var requests = 0;
    final repo = repository(
      respond: (_) async {
        requests++;
        return http.Response('[]', 200);
      },
    );
    await repo.createPayment(payment());
    await repo.createPayment(payment(id: 'pay-2', clientId: 'client-2'));
    await repo.createPayment(payment(id: 'pay-3', motelId: 'motel-2'));

    expect(await repo.findAllPayments(), hasLength(3));
    expect(
      (await repo.findPaymentsByClient(' client-1 ')).map((row) => row.id),
      ['pay-3', 'pay-1'],
    );
    expect((await repo.findPaymentsByMotel('motel-1')).map((row) => row.id), [
      'pay-2',
      'pay-1',
    ]);
    expect(await repo.findPayment('missing'), isNull);
    expect(requests, 0);
  });

  test(
    'registra y conserva un pago en el local sin consultar Supabase',
    () async {
      await repository().findPaymentMethods();
      var requests = 0;
      var repo = repository(
        respond: (_) async {
          requests++;
          throw http.ClientException('Sin conexión');
        },
      );
      await repo.createPayment(payment());
      final saved = await repo.registerLocalPayment(
        paymentId: 'pay-1',
        motelId: 'motel-1',
        paymentMethodId: 4,
      );
      expect(saved.status, PaymentStatus.paid);
      expect(saved.paymentMethodId, 4);
      expect(saved.method, isNull);
      expect(saved.paidAt, paidAt);
      expect(saved.receiptNumber, 'LOCAL-pay-1');
      expect(requests, 0);

      await database.close();
      database = await AppDatabaseProvider.open(name: path);
      repo = repository(url: '', key: '');
      expect((await repo.findPayment('pay-1'))!.receiptNumber, 'LOCAL-pay-1');
    },
  );

  test('protege la confirmación frente a dos llamadas simultáneas', () async {
    final repo = repository();
    await repo.findPaymentMethods();
    await repo.createPayment(payment());
    Future<Object> register(int methodId) async {
      try {
        return await repo.registerLocalPayment(
          paymentId: 'pay-1',
          motelId: 'motel-1',
          paymentMethodId: methodId,
        );
      } on PaymentRepositoryException catch (error) {
        return error;
      }
    }

    final results = await Future.wait([register(1), register(2)]);
    expect(results.whereType<PaymentRecord>(), hasLength(1));
    expect(
      results.whereType<PaymentRepositoryException>().single.kind,
      PaymentRepositoryError.alreadyProcessed,
    );
    final saved = results.whereType<PaymentRecord>().single;
    expect(
      (await repo.findPayment('pay-1'))!.paymentMethodId,
      saved.paymentMethodId,
    );
  });

  test('no registra pagos inexistentes ni de otro motel', () async {
    final repo = repository();
    await repo.findPaymentMethods();
    await repo.createPayment(payment());
    for (final attempt in [('missing', 'motel-1'), ('pay-1', 'other-motel')]) {
      await expectLater(
        repo.registerLocalPayment(
          paymentId: attempt.$1,
          motelId: attempt.$2,
          paymentMethodId: 1,
        ),
        throwsA(repositoryError(PaymentRepositoryError.notFound)),
      );
    }
    expect((await repo.findPayment('pay-1'))!.status, PaymentStatus.pending);
  });

  test('no registra un método que no está descargado', () async {
    final repo = repository();
    await repo.createPayment(payment());
    await expectLater(
      repo.registerLocalPayment(
        paymentId: 'pay-1',
        motelId: 'motel-1',
        paymentMethodId: 99,
      ),
      throwsA(repositoryError(PaymentRepositoryError.invalidPayment)),
    );
    expect((await repo.findPayment('pay-1'))!.paymentMethodId, isNull);
  });

  test('no modifica pagos pagados, cancelados o reembolsados', () async {
    final repo = repository();
    await repo.findPaymentMethods();
    for (final status in [
      PaymentStatus.paid,
      PaymentStatus.cancelled,
      PaymentStatus.refunded,
    ]) {
      await repo.createPayment(payment(id: status.name, status: status));
      await expectLater(
        repo.registerLocalPayment(
          paymentId: status.name,
          motelId: 'motel-1',
          paymentMethodId: 1,
        ),
        throwsA(repositoryError(PaymentRepositoryError.alreadyProcessed)),
      );
      expect((await repo.findPayment(status.name))!.status, status);
    }
  });

  test('valida los datos antes de acceder a SQLite', () async {
    final repo = repository();
    for (final invalid in [
      payment(id: ''),
      payment(id: ' pay-1 '),
      payment(clientId: ' '),
      payment(motelId: ''),
      payment(amount: 0),
      payment(amount: -1),
    ]) {
      await expectLater(
        Future.sync(() => repo.createPayment(invalid)),
        throwsA(repositoryError(PaymentRepositoryError.invalidPayment)),
      );
    }
    for (final operation in <Future<Object?> Function()>[
      () => repo.findPayment(' '),
      () => repo.findPaymentsByClient(''),
      () => repo.findPaymentsByMotel(' '),
      () => repo.registerLocalPayment(
        paymentId: '',
        motelId: 'motel-1',
        paymentMethodId: 1,
      ),
      () => repo.registerLocalPayment(
        paymentId: 'pay-1',
        motelId: '',
        paymentMethodId: 1,
      ),
      () => repo.registerLocalPayment(
        paymentId: 'pay-1',
        motelId: 'motel-1',
        paymentMethodId: 0,
      ),
    ]) {
      await expectLater(
        Future.sync(operation),
        throwsA(repositoryError(PaymentRepositoryError.invalidPayment)),
      );
    }
    expect(await repo.findAllPayments(), isEmpty);
  });

  test('insertar un ID existente no sobrescribe el pago anterior', () async {
    final repo = repository();
    await repo.createPayment(payment());
    await expectLater(
      repo.createPayment(payment(amount: 999999)),
      throwsA(repositoryError(PaymentRepositoryError.storage)),
    );
    expect((await repo.findPayment('pay-1'))!.amount, 120000);
  });
}
