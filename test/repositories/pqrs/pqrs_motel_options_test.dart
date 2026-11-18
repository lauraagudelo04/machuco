import 'package:flutter_test/flutter_test.dart';
import 'package:machuco/database/repository/image_format/pqrs_validation_repository.dart';
import 'package:machuco/database/repository/pqrs_type/pqrs_type_repository.dart';
import 'package:machuco/models/pqrs/pqrs_config_result.dart';
import 'package:machuco/models/pqrs/pqrs_image_format.dart';
import 'package:machuco/models/pqrs/pqrs_settings.dart';
import 'package:machuco/models/pqrs/pqrs_type_info.dart';
import 'package:machuco/models/booking/booking.dart';
import 'package:machuco/repositories/booking/booking_repository.dart';
import 'package:machuco/repositories/pqrs/pqrs_repository_provider.dart';

Reservation _reservation(
  String id, {
  required String motelId,
  required String motelName,
  required ReservationStatus status,
  String guestId = 'client-1',
}) => Reservation(
  id: id,
  requestId: 'req-$id',
  motelId: motelId,
  motelName: motelName,
  roomId: 'room-$id',
  roomName: 'Suite',
  roomNumber: '1',
  checkIn: DateTime(2026, 11, 1, 10),
  checkOut: DateTime(2026, 11, 1, 13),
  stayMode: StayMode.dateTimeRange,
  guestCount: 2,
  services: const [],
  products: const [],
  roomTotal: 1000,
  total: 1000,
  status: status,
  createdAt: DateTime(2026, 10, 30),
  guestId: guestId,
);

class _CountingValidation implements PqrsValidationRepository {
  int formats = 0;
  int settings = 0;

  @override
  Future<PqrsConfigResult<List<PqrsImageFormat>>> loadImageFormats() async {
    formats++;
    return const PqrsConfigResult(
      value: PqrsImageFormat.defaults,
      source: PqrsConfigSource.remote,
    );
  }

  @override
  Future<PqrsConfigResult<PqrsSettings>> loadSettings() async {
    settings++;
    return const PqrsConfigResult(
      value: PqrsSettings(),
      source: PqrsConfigSource.remote,
    );
  }
}

class _ThrowingTypes implements PqrsTypeRepository {
  int calls = 0;

  @override
  Future<PqrsConfigResult<List<PqrsTypeInfo>>> loadTypes() async {
    calls++;
    throw StateError('sin red');
  }
}

void main() {
  late BookingRepository previousBookings;
  late String? Function() previousUid;

  setUp(() {
    previousBookings = BookingRepositoryProvider.instance;
    previousUid = PqrsRepositoryProvider.currentUid;
    PqrsRepositoryProvider.currentUid = () => 'client-1';
  });

  tearDown(() {
    BookingRepositoryProvider.instance = previousBookings;
    PqrsRepositoryProvider.currentUid = previousUid;
  });

  void useReservations(List<Reservation> reservations) {
    BookingRepositoryProvider.instance = InMemoryBookingRepository(
      initial: reservations,
    );
  }

  test(
    'lista los moteles donde el cliente tiene reservas, sin repetir',
    () async {
      useReservations([
        _reservation(
          '1',
          motelId: 'm2',
          motelName: 'Zafiro',
          status: ReservationStatus.completed,
        ),
        _reservation(
          '2',
          motelId: 'm1',
          motelName: 'Aurora',
          status: ReservationStatus.active,
        ),
        _reservation(
          '3',
          motelId: 'm1',
          motelName: 'Aurora',
          status: ReservationStatus.upcoming,
        ),
      ]);

      final options = await PqrsRepositoryProvider.motelOptions();

      expect(options.map((o) => o.id), ['m1', 'm2']);
      expect(options.map((o) => o.name), ['Aurora', 'Zafiro']);
    },
  );

  test('ignora reservas canceladas, sin pagar o de otro cliente', () async {
    useReservations([
      _reservation(
        '1',
        motelId: 'm1',
        motelName: 'Aurora',
        status: ReservationStatus.cancelled,
      ),
      _reservation(
        '2',
        motelId: 'm2',
        motelName: 'Zafiro',
        status: ReservationStatus.pending,
      ),
      _reservation(
        '3',
        motelId: 'm3',
        motelName: 'Ónix',
        status: ReservationStatus.completed,
        guestId: 'otro',
      ),
    ]);

    expect(await PqrsRepositoryProvider.motelOptions(), isEmpty);
  });

  test('sin sesión no ofrece ningún motel', () async {
    PqrsRepositoryProvider.currentUid = () => null;
    useReservations([
      _reservation(
        '1',
        motelId: 'm1',
        motelName: 'Aurora',
        status: ReservationStatus.completed,
      ),
    ]);

    expect(await PqrsRepositoryProvider.motelOptions(), isEmpty);
  });

  test(
    'refreshConfiguration consulta Supabase y no falla si un origen cae',
    () async {
      final validation = _CountingValidation();
      final types = _ThrowingTypes();
      PqrsRepositoryProvider.validation = validation;
      PqrsRepositoryProvider.types = types;
      addTearDown(() {
        PqrsRepositoryProvider.validation = null;
        PqrsRepositoryProvider.types = null;
      });

      await PqrsRepositoryProvider.refreshConfiguration();

      expect(validation.formats, 1);
      expect(validation.settings, 1);
      expect(types.calls, 1);
    },
  );
}
