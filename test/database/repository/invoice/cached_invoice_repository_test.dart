import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:machuco/database/app_database.dart';
import 'package:machuco/database/repository/invoice/cached_invoice_repository.dart';
import 'package:machuco/database/repository/invoice/invoice_repository.dart';
import 'package:machuco/models/booking/booking.dart';
import 'package:machuco/models/invoice/invoice_firestore_document.dart';
import 'package:machuco/models/invoice/invoice_model.dart';
import 'package:machuco/models/payment_method/payment_method_model.dart';
import 'package:machuco/service/invoice/invoice_payment_method_source.dart';

const _offline = InvoiceRepositoryException('Sin conexión', offline: true);

Reservation _reservation(String id, {String? paymentMethod}) => Reservation(
  id: id,
  requestId: 'req-$id',
  guestId: 'client-1',
  guestName: 'Cliente Prueba',
  motelId: 'motel-1',
  motelName: 'Motel Prueba',
  roomId: 'room-1',
  roomName: 'Suite',
  roomNumber: '101',
  checkIn: DateTime.utc(2026, 10, 19, 20),
  checkOut: DateTime.utc(2026, 10, 19, 23),
  stayMode: StayMode.dateWithHourBlock,
  guestCount: 2,
  services: const [
    ReservationLineItem(
      id: 'srv-1',
      name: 'Decoración',
      unitPrice: 20000,
      quantity: 1,
    ),
  ],
  products: const [],
  roomTotal: 100000,
  total: 120000,
  status: ReservationStatus.upcoming,
  createdAt: DateTime(2026, 10, 19),
  paymentMethod: paymentMethod,
);

InvoiceFirestoreDocument _document(Reservation reservation) =>
    InvoiceFirestoreDocument(
      ownerId: 'owner-1',
      invoice: InvoiceModel.fromReservation(
        reservation,
        paymentMethod: PaymentMethodModel(amount: 120000, concept: 'Reserva')
          ..cardHolder = 'Cliente Prueba'
          ..cardNumber = '4111111111111234',
        issuedAt: DateTime.utc(2026, 10, 19, 21),
      ),
    );

/// Firestore simulado: guarda documentos en memoria o falla sin conexión.
class _FakeRemote implements FirestoreInvoiceRepository {
  final Map<String, InvoiceFirestoreDocument> documents = {};
  bool offline = false;

  void _check() {
    if (offline) throw _offline;
  }

  @override
  Future<InvoiceFirestoreDocument?> findDocument(String reservationId) async {
    _check();
    return documents[reservationId];
  }

  @override
  Future<InvoiceFirestoreDocument> issueDocument(
    Reservation reservation,
    PaymentMethodModel? paymentMethod,
  ) async {
    _check();
    return documents[reservation.id] ??= _document(reservation);
  }

  @override
  Future<List<InvoiceFirestoreDocument>> findDocumentsByClient(
    String clientId,
  ) async {
    _check();
    return documents.values
        .where((document) => document.invoice.clientId == clientId)
        .toList();
  }

  @override
  Future<List<InvoiceFirestoreDocument>> findDocumentsByOwner(
    String ownerId,
  ) async {
    _check();
    return documents.values
        .where((document) => document.ownerId == ownerId)
        .toList();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeCatalog implements InvoicePaymentMethodSource {
  bool fail = false;
  int calls = 0;

  @override
  Future<List<String>> fetchNames() async {
    calls++;
    if (fail) {
      throw const InvoicePaymentMethodSourceException('Sin conexión');
    }
    return const [
      'Efectivo',
      'Tarjeta de crédito',
      'Tarjeta de débito',
      'Transferencia bancaria',
    ];
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory directory;
  late AppDatabase database;
  late _FakeRemote remote;
  late _FakeCatalog catalog;
  late CachedInvoiceRepository repository;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('machuco_invoice_');
    database = await AppDatabaseProvider.open(
      name: '${directory.path}${Platform.pathSeparator}invoices.db',
    );
    remote = _FakeRemote();
    catalog = _FakeCatalog();
    repository = CachedInvoiceRepository(
      remote: remote,
      dao: () async => database.invoiceDao,
      paymentMethods: catalog,
    );
  });

  tearDown(() async {
    await database.close();
    await directory.delete(recursive: true);
  });

  test('emitir guarda la factura de Firebase en SQLite', () async {
    final invoice = await repository.issue(
      _reservation('res-1', paymentMethod: 'Tarjeta de crédito'),
      null,
    );

    final cached = await database.invoiceDao.findById('res-1');
    expect(cached, isNotNull);
    expect(cached!.ownerId, 'owner-1');
    expect(cached.toModel().total, invoice.total);
    expect(cached.toModel().items.single.name, 'Decoración');
    expect(cached.toModel().payment?.cardLast4, '1234');
  });

  test('resuelve el método de pago con el maestro de Supabase', () async {
    final invoice = await repository.issue(
      _reservation('res-1', paymentMethod: 'tarjeta de crédito'),
      null,
    );

    expect(invoice.paymentMethodName, 'Tarjeta de crédito');
    expect(
      (await database.invoiceDao.findById('res-1'))!.paymentMethodName,
      'Tarjeta de crédito',
    );
  });

  test('un método que no está en el maestro no se muestra', () async {
    final invoice = await repository.issue(
      _reservation('res-1', paymentMethod: 'Bitcoin'),
      null,
    );

    expect(invoice.paymentMethodName, isNull);
  });

  test('si el maestro no responde, la factura se carga igual', () async {
    catalog.fail = true;

    final invoice = await repository.issue(
      _reservation('res-1', paymentMethod: 'Efectivo'),
      null,
    );

    expect(invoice.invoiceNumber, isNotEmpty);
    expect(invoice.paymentMethodName, isNull);
  });

  test('el nombre ya resuelto se conserva sin volver al maestro', () async {
    await repository.issue(
      _reservation('res-1', paymentMethod: 'Efectivo'),
      null,
    );
    final callsAfterIssue = catalog.calls;

    final again = await repository.findByReservation(
      'res-1',
      paymentMethodHint: 'Efectivo',
    );

    expect(again?.paymentMethodName, 'Efectivo');
    expect(catalog.calls, callsAfterIssue);
  });

  test('sin conexión devuelve la copia local de SQLite', () async {
    await repository.issue(_reservation('res-1'), null);
    remote.offline = true;

    final invoice = await repository.findByReservation('res-1');

    expect(invoice?.reservationId, 'res-1');
    expect(invoice?.total, 120000);
  });

  test('sin conexión y sin copia local, propaga el error', () async {
    remote.offline = true;

    expect(
      repository.findByReservation('res-1'),
      throwsA(isA<InvoiceRepositoryException>()),
    );
  });

  test('sin conexión no se emite una factura solo en SQLite', () async {
    remote.offline = true;

    await expectLater(
      repository.issue(_reservation('res-1'), null),
      throwsA(isA<InvoiceRepositoryException>()),
    );
    expect(await database.invoiceDao.findById('res-1'), isNull);
  });

  test('listas de cliente y propietario usan la copia local sin red', () async {
    await repository.issue(_reservation('res-1'), null);
    await repository.issue(_reservation('res-2'), null);
    remote.offline = true;

    expect(await repository.findByClient('client-1'), hasLength(2));
    expect(await repository.findByOwner('owner-1'), hasLength(2));
    expect(await repository.findByOwner('otro'), isEmpty);
  });

  test('un error que no es de conexión no usa la copia local', () async {
    await repository.issue(_reservation('res-1'), null);
    final failing = CachedInvoiceRepository(
      remote: _DeniedRemote(),
      dao: () async => database.invoiceDao,
      paymentMethods: catalog,
    );

    expect(
      failing.findByReservation('res-1'),
      throwsA(
        isA<InvoiceRepositoryException>().having(
          (error) => error.offline,
          'offline',
          isFalse,
        ),
      ),
    );
  });
}

class _DeniedRemote extends _FakeRemote {
  @override
  Future<InvoiceFirestoreDocument?> findDocument(String reservationId) async =>
      throw const InvoiceRepositoryException('Sin permisos');
}
