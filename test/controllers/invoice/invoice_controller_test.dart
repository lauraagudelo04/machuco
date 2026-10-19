import 'package:flutter_test/flutter_test.dart';
import 'package:machuco/controllers/invoice/invoice_controller.dart';
import 'package:machuco/database/repository/invoice/invoice_repository.dart';
import 'package:machuco/models/booking/booking.dart';
import 'package:machuco/models/invoice/invoice_model.dart';
import 'package:machuco/models/payment_method/payment_method_model.dart';
import 'package:machuco/service/storage/shared_preferences_local_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

Reservation _reservation(
  String id, {
  ReservationStatus status = ReservationStatus.completed,
  InvoiceAccessStatus invoiceAccessStatus = InvoiceAccessStatus.notApplicable,
}) => Reservation(
  id: id,
  requestId: 'req-$id',
  motelId: 'motel-1',
  motelName: 'Motel Prueba',
  roomId: 'room-1',
  roomName: 'Suite',
  roomNumber: '101',
  checkIn: DateTime.utc(2026, 10, 19, 20),
  checkOut: DateTime.utc(2026, 10, 19, 23),
  stayMode: StayMode.dateWithHourBlock,
  guestCount: 2,
  services: const [],
  products: const [],
  roomTotal: 100000,
  total: 100000,
  status: status,
  createdAt: DateTime(2026, 10, 19),
  invoiceAccessStatus: invoiceAccessStatus,
);

InvoiceModel _invoiceFor(Reservation reservation) => InvoiceModel.fromJson({
  'id': 1,
  'invoice_number': 'FAC-000001',
  ...InvoiceModel.issuePayload(reservation, null),
  'total': reservation.roomTotal,
  'issued_at': '2026-10-19T23:00:00Z',
});

class _FakeInvoiceRepository implements InvoiceRepository {
  final Map<String, InvoiceModel> stored = {};
  int issueCalls = 0;
  bool fail = false;

  @override
  Future<InvoiceModel?> findByReservation(String reservationId) async {
    if (fail) throw const InvoiceRepositoryException('Sin conexión');
    return stored[reservationId];
  }

  @override
  Future<InvoiceModel> issue(
    Reservation reservation,
    PaymentMethodModel? paymentMethod,
  ) async {
    issueCalls++;
    return stored[reservation.id] = _invoiceFor(reservation);
  }

  @override
  Future<InvoiceModel?> findById(int id) async => null;

  @override
  Future<List<InvoiceModel>> findByClient(String clientId) async => const [];

  @override
  Future<List<InvoiceModel>> findByMotels(List<String> motelIds) async =>
      const [];
}

void main() {
  late _FakeInvoiceRepository repository;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    repository = _FakeInvoiceRepository();
  });

  InvoiceController newController() =>
      InvoiceController(repository: repository);

  group('InvoiceController carga desde el repositorio', () {
    test('usa la factura existente sin volver a emitirla', () async {
      final reservation = _reservation('res-1');
      repository.stored['res-1'] = _invoiceFor(reservation);
      final controller = newController();

      await controller.loadForReservation(reservation);

      expect(controller.status, InvoiceLoadStatus.available);
      expect(controller.invoice?.invoiceNumber, 'FAC-000001');
      expect(repository.issueCalls, 0);
    });

    test('emite la factura si la reserva está pagada y no existe', () async {
      final controller = newController();

      await controller.loadForReservation(_reservation('res-1'));

      expect(controller.status, InvoiceLoadStatus.available);
      expect(repository.issueCalls, 1);
    });

    test('pago en efectivo pendiente: no emite', () async {
      final controller = newController();

      await controller.loadForReservation(
        _reservation('res-1', invoiceAccessStatus: InvoiceAccessStatus.pending),
      );

      expect(controller.status, InvoiceLoadStatus.pending);
      expect(repository.issueCalls, 0);
    });

    test('reserva cancelada: no hay factura', () async {
      final controller = newController();

      await controller.loadForReservation(
        _reservation('res-1', status: ReservationStatus.cancelled),
      );

      expect(controller.status, InvoiceLoadStatus.notAvailable);
      expect(repository.issueCalls, 0);
    });

    test('reserva pendiente que viene del flujo de pago: emite', () async {
      final controller = newController();

      await controller.loadForReservation(
        _reservation('res-1', status: ReservationStatus.pending),
        paymentMethod: PaymentMethodModel(amount: 100000, concept: 'Reserva'),
      );

      expect(controller.status, InvoiceLoadStatus.available);
    });

    test('error del repositorio se expone como estado de error', () async {
      repository.fail = true;
      final controller = newController();

      await controller.loadForReservation(_reservation('res-1'));

      expect(controller.status, InvoiceLoadStatus.error);
      expect(controller.errorMessage, 'Sin conexión');
    });
  });

  group('InvoiceController preferencias', () {
    test('sin preferencias guardadas no hay descargas', () async {
      final controller = newController();
      await controller.loadPreferences();

      expect(controller.isDownloaded('res-1'), isFalse);
      expect(controller.lastDownloadedAt, isNull);
    });

    test('sin factura cargada no descarga', () async {
      expect(await newController().downloadCurrent(), isFalse);
    });

    test('recuerda la descarga entre instancias (sesiones)', () async {
      final first = newController();
      await first.loadForReservation(_reservation('res-1'));
      expect(await first.downloadCurrent(), isTrue);

      final second = newController();
      await second.loadPreferences();

      expect(second.isDownloaded('res-1'), isTrue);
      expect(second.isDownloaded('res-2'), isFalse);
      expect(second.lastDownloadedAt, isNotNull);
    });

    test('usa su propio namespace y no guarda datos de pago', () async {
      final controller = newController();
      await controller.loadForReservation(_reservation('res-1'));
      await controller.downloadCurrent();

      final keys = (await SharedPreferences.getInstance()).getKeys();
      expect(keys, everyElement(startsWith('invoices.')));
      expect(
        await SharedPreferencesLocalService(
          namespace: 'invoices',
        ).getStringList('downloadedReservationIds'),
        ['res-1'],
      );
    });
  });
}
