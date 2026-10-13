import 'package:flutter_test/flutter_test.dart';

import 'package:machuco/controllers/booking/client_view/client_booking_controller.dart';
import 'package:machuco/controllers/booking/owner_view/owner_booking_controller.dart';
import 'package:machuco/controllers/booking/system_admin_view/system_admin_booking_controller.dart';
import 'package:machuco/models/booking/booking.dart';
import 'package:machuco/repositories/booking/booking_repository.dart';
import 'package:machuco/repositories/booking/booking_seed_data.dart';
import 'package:machuco/service/booking/booking_service.dart';

void main() {
  group('InMemoryBookingRepository', () {
    test('seed has unique ids and request ids, and no reservations in '
        'motel 3', () async {
      final repository = InMemoryBookingRepository();

      final all = await repository.getAll();

      expect(all.map((r) => r.id).toSet().length, all.length);
      expect(all.map((r) => r.requestId).toSet().length, all.length);
      expect(all.where((r) => r.motelId == '3'), isEmpty);
    });

    test('add, update, getById and findByRequestId', () async {
      final repository = InMemoryBookingRepository(
        initial: buildSeedReservations(DateTime.now()),
      );
      final seeded = (await repository.getAll()).first;

      expect(await repository.getById(seeded.id), same(seeded));
      expect(await repository.findByRequestId(seeded.requestId), same(seeded));
      expect(await repository.getById('missing'), isNull);

      final cancelled = seeded.copyWith(status: ReservationStatus.cancelled);
      await repository.update(cancelled);
      expect(await repository.getById(seeded.id), same(cancelled));

      final before = (await repository.getAll()).length;
      await repository.update(
        seeded.copyWith(status: ReservationStatus.active).copyWith(),
      );
      expect((await repository.getAll()).length, before);
    });

    test('update of an unknown id does nothing', () async {
      final repository = InMemoryBookingRepository(initial: const []);
      final seeded = buildSeedReservations(DateTime.now()).first;

      await repository.update(seeded);

      expect(await repository.getAll(), isEmpty);
    });
  });

  group('shared visibility between roles', () {
    late BookingRepository repository;
    late ClientBookingController client;
    late OwnerBookingController owner;
    late SystemAdminBookingController admin;

    setUp(() {
      repository = InMemoryBookingRepository();
      BookingService service() => BookingService(repository: repository);
      client = ClientBookingController(bookingService: service());
      owner = OwnerBookingController(bookingService: service());
      admin = SystemAdminBookingController(bookingService: service());
    });

    tearDown(() {
      client.dispose();
      owner.dispose();
      admin.dispose();
    });

    Future<Reservation> createAsClient() async {
      final now = DateTime.now();
      final result = await client.createReservation(
        requestId: 'req-shared-1',
        // Motel '1' belongs to the demo owner.
        motelId: '1',
        motelName: 'Motel Paraíso Élite',
        roomId: 'room-shared-test',
        roomName: 'Suite Prueba',
        roomNumber: '999',
        checkIn: now.add(const Duration(days: 30)),
        checkOut: now.add(const Duration(days: 30, hours: 4)),
        stayMode: StayMode.dateTimeRange,
        guestCount: 2,
        services: const [],
        products: const [],
        roomTotal: 120000,
      );
      expect(result.isSuccess, isTrue);
      return result.reservation!;
    }

    test(
      'a reservation created by the client is visible to owner and admin',
      () async {
        final adminBefore = await admin.historicalReservationsTotal('1');
        final ownerBefore = (await owner.reservationsForOwner(
          OwnerBookingController.demoOwnerId,
        )).length;

        final created = await createAsClient();

        final ownerView = await owner.reservationsForOwner(
          OwnerBookingController.demoOwnerId,
        );
        expect(ownerView.length, ownerBefore + 1);
        expect(ownerView.where((r) => r.id == created.id), hasLength(1));
        expect(
          (await owner.getById(created.id))!.status,
          ReservationStatus.pending,
        );
        expect(await admin.historicalReservationsTotal('1'), adminBefore + 1);
        expect(client.getById(created.id), isNotNull);
      },
    );

    test(
      'the very same reservation objects are served to every role',
      () async {
        await client.refresh();
        const id = 'reservation-seed-upcoming';

        final fromClient = client.getById(id)!;
        final fromOwner = (await owner.getById(id))!;

        expect(fromOwner, same(fromClient));
      },
    );

    test('a client only sees its own reservations', () async {
      await client.refresh();

      expect(client.reservations, isNotEmpty);
      expect(
        client.reservations.every((r) => r.guestId == client.userId),
        isTrue,
      );
      expect(client.getById('owner-reservation-001'), isNull);
    });

    test('an owner cancellation is seen by the client', () async {
      final created = await createAsClient();

      await owner.cancelReservation(created.id, 'Mantenimiento de la sala');
      await client.refresh();

      final seenByClient = client.getById(created.id)!;
      expect(seenByClient.status, ReservationStatus.cancelled);
      expect(seenByClient.cancellationReason, 'Mantenimiento de la sala');
    });

    test('a client payment is seen by the owner, and a slot taken by one '
        'role is blocked for the other', () async {
      final created = await createAsClient();

      expect(await client.confirmPayment(created.id), isTrue);

      expect(
        (await owner.getById(created.id))!.status,
        ReservationStatus.upcoming,
      );
      expect(
        client.isSlotAvailable(
          'room-shared-test',
          created.checkIn,
          created.checkOut,
        ),
        isFalse,
      );
    });
  });
}
