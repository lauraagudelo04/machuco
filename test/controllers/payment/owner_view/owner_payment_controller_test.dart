import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:machuco/controllers/payment/owner_view/owner_payment_controller.dart';
import 'package:machuco/database/app_database.dart';
import 'package:machuco/models/payment/payment.dart';
import 'package:machuco/repositories/payment/payment_repository.dart';
import 'package:machuco/repositories/payment/payment_cloud_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final controllers = <OwnerPaymentController>[];
  final paidAt = DateTime(2026, 10, 16, 21, 30);
  late Directory directory;
  late String path;
  late AppDatabase database;
  late http.Client client;
  late _ControlledRepository repository;
  late int requests;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('machuco_owner_payment_');
    path = '${directory.path}${Platform.pathSeparator}payments.db';
    database = await AppDatabaseProvider.open(name: path);
    requests = 0;
    client = MockClient((_) async {
      requests++;
      return http.Response.bytes(
        utf8.encode(
          jsonEncode([
            {'id': 1, 'nombre': 'Efectivo'},
            {'id': 2, 'nombre': 'Tarjeta de crédito'},
            {'id': 3, 'nombre': 'Tarjeta de débito'},
            {'id': 4, 'nombre': 'Transferencia bancaria'},
          ]),
        ),
        200,
      );
    });
    repository = _ControlledRepository(database, client, paidAt);
  });

  tearDown(() async {
    for (final controller in controllers) {
      controller.dispose();
    }
    controllers.clear();
    client.close();
    await database.close();
    await directory.delete(recursive: true);
  });

  PaymentRecord payment({
    String id = 'pay-1',
    String motelId = 'motel-1',
    String clientId = 'client-1',
    PaymentStatus status = PaymentStatus.pending,
    int amount = 120000,
  }) => PaymentRecord(
    id: id,
    bookingId: 'booking-$id',
    bookingReference: 'RES-$id',
    clientId: clientId,
    client: 'Carlos Ruiz',
    motelId: motelId,
    motel: 'Motel de prueba',
    roomId: 'room-1',
    room: 'Habitación 1',
    reservationDate: DateTime(2026, 10, 16),
    amount: amount,
    status: status,
  );

  Future<OwnerPaymentController> controller() async {
    final result = OwnerPaymentController(
      motelId: 'motel-1',
      repository: repository,
    );
    controllers.add(result);
    await result.ready;
    return result;
  }

  test('elimina fixtures legados antes de sincronizar pagos reales', () async {
    await repository.createPayment(payment(id: 'pay-001'));
    await repository.createPayment(payment(id: 'real-payment'));
    final cloud = _FakePaymentCloudRepository();
    final owner = OwnerPaymentController(
      motelId: 'motel-1',
      repository: repository,
      cloudRepository: cloud,
      currentUserId: () => 'firebase-owner',
    );
    controllers.add(owner);
    await owner.ready;

    expect(await repository.findPayment('pay-001'), isNull);
    expect(owner.payments.single.id, 'real-payment');
    expect(cloud.saved.map((record) => record.payment.id), ['real-payment']);
  });

  test(
    'carga pagos de SQLite solo para su motel sin consultar la red',
    () async {
      await repository.createPayment(payment());
      await repository.createPayment(payment(id: 'other', motelId: 'motel-2'));
      final owner = await controller();
      expect(owner.payments.single.id, 'pay-1');
      expect(owner.pendingAmount, 120000);
      expect(owner.isLoading, isFalse);
      expect(owner.errorMessage, isNull);
      expect(requests, 0);
    },
  );

  test('sincroniza SQLite y Firebase filtrando propietario y motel', () async {
    await repository.findPaymentMethods();
    await repository.createPayment(
      payment(id: 'local-pay', status: PaymentStatus.paid).copyWith(
        paymentMethodId: 1,
        paidAt: paidAt,
        receiptNumber: 'LOCAL-local-pay',
      ),
    );
    final cloud = _FakePaymentCloudRepository(
      remotePayments: [payment(id: 'remote-pay')],
    );
    final owner = OwnerPaymentController(
      motelId: 'motel-1',
      repository: repository,
      cloudRepository: cloud,
      currentUserId: () => 'firebase-owner',
    );
    controllers.add(owner);
    await owner.ready;

    expect(cloud.saved.map((record) => record.payment.id), ['local-pay']);
    expect(cloud.saved.single.paymentMethodName, 'Efectivo');
    expect(cloud.requestedOwnerId, 'firebase-owner');
    expect(cloud.requestedMotelId, 'motel-1');
    expect(owner.payments.map((record) => record.id).toSet(), {
      'local-pay',
      'remote-pay',
    });
    expect(owner.syncWarningMessage, isNull);
  });

  test(
    'un fallo de Firebase no elimina ni invalida los pagos locales',
    () async {
      await repository.createPayment(payment());
      final cloud = _FakePaymentCloudRepository(failSave: true);
      final owner = OwnerPaymentController(
        motelId: 'motel-1',
        repository: repository,
        cloudRepository: cloud,
        currentUserId: () => 'firebase-owner',
      );
      controllers.add(owner);
      await owner.ready;

      expect(owner.payments.single.id, 'pay-1');
      expect(owner.syncWarningMessage, contains('Sin conexión'));
      expect(
        (await repository.findPayment('pay-1'))!.status,
        PaymentStatus.pending,
      );
    },
  );

  test('sin sesión conserva SQLite y no consulta Firebase', () async {
    await repository.createPayment(payment());
    final cloud = _FakePaymentCloudRepository();
    final owner = OwnerPaymentController(
      motelId: 'motel-1',
      repository: repository,
      cloudRepository: cloud,
      currentUserId: () => null,
    );
    controllers.add(owner);
    await owner.ready;

    expect(owner.payments, hasLength(1));
    expect(cloud.saved, isEmpty);
    expect(cloud.requestedOwnerId, isNull);
    expect(owner.syncWarningMessage, contains('Inicia sesión'));
  });

  test('descarga el maestro al solicitarlo y conserva sus nombres', () async {
    await repository.createPayment(payment());
    final owner = await controller();
    expect(requests, 0);
    final methods = await owner.loadPaymentMethods();
    expect(methods.map((entry) => entry.id), [1, 2, 3, 4]);
    expect(requests, 1);
    expect(
      owner.methodName(payment().copyWith(paymentMethodId: 3)),
      'Tarjeta de débito',
    );
  });

  test(
    'registra con el método seleccionado y recalcula los indicadores',
    () async {
      await repository.createPayment(payment());
      final owner = await controller();
      await owner.loadPaymentMethods();
      final saved = await owner.registerLocalPayment(
        paymentId: 'pay-1',
        paymentMethodId: 4,
      );
      expect(saved.status, PaymentStatus.paid);
      expect(owner.pendingPayments, isEmpty);
      expect(owner.completedPayments.single.paymentMethodId, 4);
      expect(owner.methodName(saved), 'Transferencia bancaria');
      expect(saved.paidAt, paidAt);
      expect(saved.receiptNumber, 'LOCAL-pay-1');
      expect(owner.pendingAmount, 0);
      expect(owner.totalIncome, 120000);
      expect(owner.paymentsReceived, 1);
      expect(owner.frequentClients.single.totalPaid, 120000);
    },
  );

  test('un error al guardar no mueve el pago ni altera los totales', () async {
    await repository.createPayment(payment());
    final owner = await controller();
    await owner.loadPaymentMethods();
    repository.failSave = true;
    await expectLater(
      owner.registerLocalPayment(paymentId: 'pay-1', paymentMethodId: 1),
      throwsA(isA<PaymentRepositoryException>()),
    );
    expect(owner.pendingPayments.single.status, PaymentStatus.pending);
    expect(owner.completedPayments, isEmpty);
    expect(owner.totalIncome, 0);
    expect(owner.isSaving, isFalse);
    expect(
      (await repository.findPayment('pay-1'))!.status,
      PaymentStatus.pending,
    );
    repository.failSave = false;
    await owner.registerLocalPayment(paymentId: 'pay-1', paymentMethodId: 1);
    expect(owner.completedPayments, hasLength(1));
  });

  test('bloquea el doble envío y no muestra éxito antes de guardar', () async {
    await repository.createPayment(payment());
    final owner = await controller();
    await owner.loadPaymentMethods();
    repository.saveGate = Completer<void>();
    final saving = owner.registerLocalPayment(
      paymentId: 'pay-1',
      paymentMethodId: 3,
    );
    expect(owner.isSaving, isTrue);
    expect(owner.pendingPayments, hasLength(1));
    expect(owner.completedPayments, isEmpty);
    await expectLater(
      owner.registerLocalPayment(paymentId: 'pay-1', paymentMethodId: 4),
      throwsA(isA<PaymentRepositoryException>()),
    );
    repository.saveGate!.complete();
    await saving;
    expect(owner.isSaving, isFalse);
    expect(owner.completedPayments.single.paymentMethodId, 3);
  });

  test('permite reintentar una carga fallida', () async {
    repository.failLoad = true;
    final owner = await controller();
    expect(owner.errorMessage, 'No se pudo leer SQLite.');
    expect(owner.isLoading, isFalse);
    repository.failLoad = false;
    await repository.createPayment(payment());
    await owner.load();
    expect(owner.errorMessage, isNull);
    expect(owner.payments, hasLength(1));
  });

  test('no cuenta cancelados o reembolsados como pagos realizados', () async {
    await repository.createPayment(payment());
    await repository.createPayment(
      payment(id: 'paid', status: PaymentStatus.paid, amount: 50000),
    );
    await repository.createPayment(
      payment(id: 'refund', status: PaymentStatus.refunded),
    );
    await repository.createPayment(
      payment(id: 'cancel', status: PaymentStatus.cancelled),
    );
    final owner = await controller();
    expect(owner.completedPayments.single.id, 'paid');
    expect(owner.otherPayments, hasLength(2));
    expect(owner.pendingAmount, 120000);
    expect(owner.totalIncome, 50000);
    expect(owner.paymentsReceived, 1);
    expect(owner.frequentClients.single.reservations, 3);
    expect(owner.frequentClients.single.totalPaid, 50000);
  });

  test(
    'no infiere métodos de pagos online ni inventa nombres ausentes',
    () async {
      final owner = await controller();
      expect(
        owner.methodName(payment().copyWith(method: PaymentMethod.online)),
        'Pago en línea',
      );
      expect(
        owner.methodName(payment().copyWith(paymentMethodId: 99)),
        'Método #99',
      );
    },
  );

  test('no notifica a una pantalla eliminada durante el guardado', () async {
    await repository.createPayment(payment());
    final owner = await controller();
    await owner.loadPaymentMethods();
    repository.saveGate = Completer<void>();
    final saving = owner.registerLocalPayment(
      paymentId: 'pay-1',
      paymentMethodId: 1,
    );
    owner.dispose();
    controllers.remove(owner);
    repository.saveGate!.complete();
    expect((await saving).status, PaymentStatus.paid);
  });
}

class _ControlledRepository extends PaymentRepository {
  _ControlledRepository(
    AppDatabase database,
    http.Client client,
    DateTime paidAt,
  ) : super(
        database: database,
        client: client,
        supabaseUrl: 'https://example.supabase.co',
        publishableKey: 'test-key',
        now: () => paidAt,
      );

  bool failLoad = false;
  bool failSave = false;
  Completer<void>? saveGate;

  @override
  Future<List<PaymentRecord>> findPaymentsByMotel(String motelId) {
    if (failLoad) {
      throw const PaymentRepositoryException(
        PaymentRepositoryError.storage,
        'No se pudo leer SQLite.',
      );
    }
    return super.findPaymentsByMotel(motelId);
  }

  @override
  Future<PaymentRecord> registerLocalPayment({
    required String paymentId,
    required String motelId,
    required int paymentMethodId,
  }) async {
    await saveGate?.future;
    if (failSave) {
      throw const PaymentRepositoryException(
        PaymentRepositoryError.storage,
        'No se pudo guardar el pago.',
      );
    }
    return super.registerLocalPayment(
      paymentId: paymentId,
      motelId: motelId,
      paymentMethodId: paymentMethodId,
    );
  }
}

class _SavedCloudPayment {
  const _SavedCloudPayment(this.ownerId, this.payment, this.paymentMethodName);

  final String ownerId;
  final PaymentRecord payment;
  final String? paymentMethodName;
}

class _FakePaymentCloudRepository implements PaymentCloudRepository {
  _FakePaymentCloudRepository({
    this.remotePayments = const [],
    this.failSave = false,
  });

  final List<PaymentRecord> remotePayments;
  final bool failSave;
  final List<_SavedCloudPayment> saved = [];
  String? requestedOwnerId;
  String? requestedMotelId;

  @override
  Future<void> savePayment({
    required String ownerId,
    required PaymentRecord payment,
    String? paymentMethodName,
  }) async {
    if (failSave) {
      throw const PaymentCloudRepositoryException(
        PaymentCloudFailureType.network,
        'Sin conexión: el pago permanece guardado en este dispositivo.',
      );
    }
    saved.add(_SavedCloudPayment(ownerId, payment, paymentMethodName));
  }

  @override
  Future<List<PaymentRecord>> listForOwnerAndMotel({
    required String ownerId,
    required String motelId,
  }) async {
    requestedOwnerId = ownerId;
    requestedMotelId = motelId;
    return remotePayments;
  }
}
