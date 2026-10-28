import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:machuco/controllers/payment/owner_view/owner_payment_controller.dart';
import 'package:machuco/controllers/payment/payment_store.dart';
import 'package:machuco/database/app_database.dart';
import 'package:machuco/models/payment/payment.dart';
import 'package:machuco/repositories/payment/payment_repository.dart';

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

  Future<OwnerPaymentController> controller({
    bool useDemoData = false,
    PaymentStore? store,
  }) async {
    final result = OwnerPaymentController(
      motelId: 'motel-1',
      repository: repository,
      useDemoData: useDemoData,
      store: store,
    );
    controllers.add(result);
    await result.ready;
    return result;
  }

  test('no importa ejemplos sin habilitar el modo de demostración', () async {
    final owner = await controller(
      store: PaymentStore.seeded(payments: [payment()]),
    );
    expect(owner.payments, isEmpty);
    expect(await repository.findAllPayments(), isEmpty);
    expect(requests, 0);
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

  test('los ejemplos no recrean pendientes al reabrir la base', () async {
    final store = PaymentStore.seeded(
      payments: [
        payment(),
        payment(id: 'other', motelId: 'motel-2'),
      ],
    );
    final first = await controller(useDemoData: true, store: store);
    expect(first.payments, hasLength(1));
    await first.loadPaymentMethods();
    await first.registerLocalPayment(paymentId: 'pay-1', paymentMethodId: 2);
    await first.load();
    expect(first.pendingPayments, isEmpty);

    first.dispose();
    controllers.remove(first);
    await database.close();
    database = await AppDatabaseProvider.open(name: path);
    repository = _ControlledRepository(database, client, paidAt);
    final restored = await controller(useDemoData: true, store: store);
    expect(restored.pendingPayments, isEmpty);
    expect(restored.completedPayments.single.receiptNumber, 'LOCAL-pay-1');
    expect(
      restored.methodName(restored.completedPayments.single),
      'Tarjeta de crédito',
    );
    expect(await repository.findPaymentsByMotel('motel-2'), isEmpty);
    expect(store.payments.first.status, PaymentStatus.pending);
  });

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
