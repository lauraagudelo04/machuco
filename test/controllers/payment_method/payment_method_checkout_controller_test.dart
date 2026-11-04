import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:machuco/controllers/payment_method/payment_method_checkout_controller.dart';
import 'package:machuco/database/app_database.dart';
import 'package:machuco/models/booking/booking.dart';
import 'package:machuco/models/payment/payment.dart';
import 'package:machuco/models/payment_method/payment_method_model.dart';
import 'package:machuco/repositories/payment/payment_cloud_repository.dart';
import 'package:machuco/repositories/payment/payment_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _FakeCloud implements PaymentCloudRepository {
  _FakeCloud({this.failure});

  final PaymentCloudRepositoryException? failure;
  final saved = <({String ownerId, PaymentRecord payment, String? name})>[];

  @override
  Future<void> savePayment({
    required String ownerId,
    required PaymentRecord payment,
    String? paymentMethodName,
  }) async {
    if (failure != null) throw failure!;
    saved.add((ownerId: ownerId, payment: payment, name: paymentMethodName));
  }

  @override
  Future<List<PaymentRecord>> listForOwnerAndMotel({
    required String ownerId,
    required String motelId,
  }) async => const [];
}

void main() {
  final now = DateTime(2026, 11, 3, 18, 0);
  final catalog = [
    {'id': 1, 'nombre': 'Efectivo'},
    {'id': 2, 'nombre': 'Tarjeta de crédito'},
    {'id': 3, 'nombre': 'Tarjeta de débito'},
    {'id': 4, 'nombre': 'Transferencia bancaria'},
  ];
  late Directory directory;
  late AppDatabase database;
  late http.Client client;
  late PaymentRepository repository;

  final reservation = Reservation(
    id: 'res-1',
    requestId: 'req-1',
    motelId: 'motel-1',
    motelName: 'Motel Uno',
    roomId: 'room-208',
    roomName: 'Deluxe',
    roomNumber: '208',
    checkIn: DateTime(2026, 11, 10, 17),
    checkOut: DateTime(2026, 11, 10, 20),
    stayMode: StayMode.dateTimeRange,
    guestCount: 2,
    services: const [],
    products: const [],
    roomTotal: 156000,
    total: 156000,
    status: ReservationStatus.pending,
    createdAt: DateTime(2026, 11, 3, 17),
  );

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('machuco_checkout_');
    database = await AppDatabaseProvider.open(
      name: '${directory.path}${Platform.pathSeparator}payments.db',
    );
    client = MockClient(
      (_) async => http.Response.bytes(utf8.encode(jsonEncode(catalog)), 200),
    );
    repository = PaymentRepository(
      database: database,
      client: client,
      supabaseUrl: 'https://example.supabase.co',
      publishableKey: 'publishable-test-key',
      now: () => now,
    );
  });

  tearDown(() async {
    client.close();
    await database.close();
    await directory.delete(recursive: true);
  });

  PaymentCheckoutController controller({
    PaymentCloudRepository? cloud,
    String? uid = 'client-uid',
    String? ownerId = 'owner-uid',
  }) => PaymentCheckoutController(
    repository: repository,
    cloudRepository: cloud,
    ownerIdForMotel: (_) async => ownerId,
    currentUserId: () => uid,
    currentUserName: () => 'cliente@machuco.com',
    now: () => now,
  );

  test('En el Local crea un pago pendiente sin método y lo sincroniza', () async {
    final cloud = _FakeCloud();

    final result = await controller(
      cloud: cloud,
    ).registerPendingLocalPayment(reservation);

    expect(result.syncWarning, isNull);
    expect(result.payment.status, PaymentStatus.pending);
    expect(result.payment.paymentMethodId, isNull);
    expect(result.payment.paidAt, isNull);
    expect(result.payment.receiptNumber, isNull);
    expect(result.payment.clientId, 'client-uid');
    expect(result.payment.amount, 156000);
    expect(result.payment.reservationDate, reservation.checkIn);
    expect(result.payment.room, 'Habitación 208 · Deluxe');

    final stored = await repository.findPayment(result.payment.id);
    expect(stored?.status, PaymentStatus.pending);
    expect(cloud.saved.single.ownerId, 'owner-uid');
    expect(cloud.saved.single.name, isNull);
  });

  test('tarjeta de crédito crea el pago pagado con el método 2', () async {
    final cloud = _FakeCloud();

    final result = await controller(cloud: cloud).registerCardPayment(
      reservation,
      kind: CardPaymentKind.credit,
    );

    expect(result.payment.status, PaymentStatus.paid);
    expect(result.payment.paymentMethodId, 2);
    expect(result.payment.paidAt, now);
    expect(result.payment.receiptNumber, 'CARD-pay-res-1');
    expect(cloud.saved.single.name, 'Tarjeta de crédito');
  });

  test('tarjeta de débito usa el método 3 del maestro', () async {
    final result = await controller().registerCardPayment(
      reservation,
      kind: CardPaymentKind.debit,
    );

    expect(result.payment.paymentMethodId, 3);
  });

  test('sin sesión de Firebase guarda local y avisa que no sincronizó', () async {
    final cloud = _FakeCloud();

    final result = await controller(
      cloud: cloud,
      uid: null,
    ).registerPendingLocalPayment(reservation);

    expect(result.syncWarning, contains('Firebase'));
    expect(cloud.saved, isEmpty);
    expect(await repository.findPayment(result.payment.id), isNotNull);
  });

  test('si Firebase falla el pago local se conserva y se avisa', () async {
    final cloud = _FakeCloud(
      failure: const PaymentCloudRepositoryException(
        PaymentCloudFailureType.permissionDenied,
        'No tienes permisos para sincronizar los pagos de este motel.',
      ),
    );

    final result = await controller(
      cloud: cloud,
    ).registerPendingLocalPayment(reservation);

    expect(result.syncWarning, contains('No tienes permisos'));
    expect(await repository.findPayment(result.payment.id), isNotNull);
  });

  test('si el motel no tiene propietario conocido avisa y no sincroniza', () async {
    final cloud = _FakeCloud();

    final result = await controller(
      cloud: cloud,
      ownerId: null,
    ).registerPendingLocalPayment(reservation);

    expect(result.syncWarning, contains('propietario'));
    expect(cloud.saved, isEmpty);
  });

  test('repetir En el Local es idempotente y no duplica en la nube', () async {
    final cloud = _FakeCloud();
    final checkout = controller(cloud: cloud);

    await checkout.registerPendingLocalPayment(reservation);
    final second = await checkout.registerPendingLocalPayment(reservation);

    expect(second.payment.status, PaymentStatus.pending);
    expect(cloud.saved, hasLength(1));
  });

  test('pagar con tarjeta una reserva ya pendiente se rechaza', () async {
    final checkout = controller();
    await checkout.registerPendingLocalPayment(reservation);

    expect(
      () => checkout.registerCardPayment(
        reservation,
        kind: CardPaymentKind.credit,
      ),
      throwsA(
        isA<PaymentRepositoryException>().having(
          (error) => error.kind,
          'kind',
          PaymentRepositoryError.alreadyProcessed,
        ),
      ),
    );
  });
}
