import 'package:flutter_test/flutter_test.dart';

import 'package:machuco/controllers/booking/owner_view/owner_booking_controller.dart';
import 'package:machuco/models/booking/booking.dart';

void main() {
  group('OwnerBookingController.reservationsForOwner', () {
    test('devuelve solo reservas de los moteles del propietario, ordenadas '
        'de más reciente a más antigua', () async {
      final controller = OwnerBookingController();

      final owned = await controller.reservationsForOwner(
        OwnerBookingController.demoOwnerId,
      );

      expect(owned, isNotEmpty);
      expect(owned.every((r) => r.motelId == '1' || r.motelId == '2'), isTrue);
      for (var i = 0; i < owned.length - 1; i++) {
        expect(
          owned[i].createdAt.isAfter(owned[i + 1].createdAt) ||
              owned[i].createdAt.isAtSameMomentAs(owned[i + 1].createdAt),
          isTrue,
          reason:
              'La lista debe venir ordenada de más reciente a más '
              'antigua (posición $i vs ${i + 1}).',
        );
      }
    });

    test('un propietario sin moteles conocidos no recibe reservas', () async {
      final controller = OwnerBookingController(ownerId: 'owner-inexistente');

      final owned = await controller.reservationsForOwner('owner-inexistente');

      expect(owned, isEmpty);
    });
  });

  group('OwnerBookingController.filteredReservations', () {
    test('combina filtros de motel, habitación, cliente y estado', () async {
      final controller = OwnerBookingController();
      final ground = await controller.reservationsForOwner(controller.ownerId);

      final byMotel = await controller.filteredReservations(motelId: '2');
      expect(byMotel, ground.where((r) => r.motelId == '2').toList());

      final byStatus = await controller.filteredReservations(
        status: ReservationStatus.pending,
      );
      expect(
        byStatus,
        ground.where((r) => r.status == ReservationStatus.pending).toList(),
      );

      final byRoom = await controller.filteredReservations(
        roomId: 'room-1-101',
      );
      expect(byRoom, ground.where((r) => r.roomId == 'room-1-101').toList());

      final byClient = await controller.filteredReservations(
        clientId: 'client-001',
      );
      expect(byClient, ground.where((r) => r.guestId == 'client-001').toList());

      final combined = await controller.filteredReservations(
        motelId: '1',
        clientId: 'client-001',
      );
      expect(
        combined,
        ground
            .where((r) => r.motelId == '1' && r.guestId == 'client-001')
            .toList(),
      );
    });

    test(
      'sin filtros devuelve el mismo conjunto que reservationsForOwner',
      () async {
        final controller = OwnerBookingController();
        final ground = await controller.reservationsForOwner(
          controller.ownerId,
        );

        final filtered = await controller.filteredReservations();

        expect(filtered, ground);
      },
    );

    test(
      'una combinación sin coincidencias devuelve una lista vacía',
      () async {
        final controller = OwnerBookingController();

        final result = await controller.filteredReservations(
          motelId: '1',
          clientId: 'cliente-que-no-existe',
        );

        expect(result, isEmpty);
      },
    );
  });

  group('OwnerBookingController.reservationsForClient', () {
    test(
      'reutiliza filteredReservations y limita al propietario actual',
      () async {
        final controller = OwnerBookingController();
        final ground = await controller.reservationsForOwner(
          controller.ownerId,
        );
        final expected = ground
            .where((r) => r.guestId == 'client-001')
            .toList();

        final result = await controller.reservationsForClient(
          controller.ownerId,
          'client-001',
        );

        expect(result, expected);
        expect(result, isNotEmpty);
        expect(result.every((r) => r.guestId == 'client-001'), isTrue);
      },
    );
  });

  group('OwnerBookingController.cancelReservation', () {
    test(
      'rechaza un motivo vacío y no cambia el estado de la reserva',
      () async {
        final controller = OwnerBookingController();
        const reservationId = 'owner-reservation-006';

        final before = await controller.getById(reservationId);
        expect(before!.status, ReservationStatus.pending);

        await expectLater(
          controller.cancelReservation(reservationId, '   '),
          throwsA(
            isA<ReservationCancellationException>().having(
              (e) => e.reason,
              'reason',
              ReservationCancellationError.reasonRequired,
            ),
          ),
        );

        final after = await controller.getById(reservationId);
        expect(after!.status, ReservationStatus.pending);
        expect(after.cancellationReason, isNull);
      },
    );

    test('cancela una reserva pending con motivo válido', () async {
      final controller = OwnerBookingController();
      const reservationId = 'owner-reservation-006';

      await controller.cancelReservation(
        reservationId,
        'El huésped canceló por cambio de planes.',
      );

      final after = await controller.getById(reservationId);
      expect(after!.status, ReservationStatus.cancelled);
      expect(
        after.cancellationReason,
        'El huésped canceló por cambio de planes.',
      );
    });

    test('cancela una reserva upcoming con motivo válido', () async {
      final controller = OwnerBookingController();
      const reservationId = 'owner-reservation-002';

      final before = await controller.getById(reservationId);
      expect(before!.status, ReservationStatus.upcoming);

      await controller.cancelReservation(reservationId, 'Reprogramación');

      final after = await controller.getById(reservationId);
      expect(after!.status, ReservationStatus.cancelled);
      expect(after.cancellationReason, 'Reprogramación');
    });

    test('rechaza cancelar reservas en estados no cancelables (active, '
        'completed, cancelled)', () async {
      final controller = OwnerBookingController();

      for (final reservationId in [
        'owner-reservation-001', // active
        'owner-reservation-004', // completed
        'owner-reservation-005', // cancelled desde el seed
      ]) {
        await expectLater(
          controller.cancelReservation(reservationId, 'Motivo cualquiera'),
          throwsA(
            isA<ReservationCancellationException>().having(
              (e) => e.reason,
              'reason',
              ReservationCancellationError.invalidStatus,
            ),
          ),
          reason: 'reservationId=$reservationId debería ser rechazado',
        );
      }
    });

    test('lanza notFound si el id de la reserva no existe', () async {
      final controller = OwnerBookingController();

      await expectLater(
        controller.cancelReservation('no-existe', 'Motivo'),
        throwsA(
          isA<ReservationCancellationException>().having(
            (e) => e.reason,
            'reason',
            ReservationCancellationError.notFound,
          ),
        ),
      );
    });
  });

  group('OwnerBookingController.registerCashPayment', () {
    test('transiciona una reserva pending a upcoming/active y marca la '
        'factura como pendiente', () async {
      final controller = OwnerBookingController();
      const reservationId = 'owner-reservation-003';

      final before = await controller.getById(reservationId);
      expect(before!.status, ReservationStatus.pending);
      final expectNextStatus = DateTime.now().isBefore(before.checkIn)
          ? ReservationStatus.upcoming
          : ReservationStatus.active;

      await controller.registerCashPayment(reservationId);

      final after = await controller.getById(reservationId);
      expect(after!.status, expectNextStatus);
      expect(after.invoiceAccessStatus, InvoiceAccessStatus.pending);
    });

    test('lanza notFound si el id de la reserva no existe', () async {
      final controller = OwnerBookingController();

      await expectLater(
        controller.registerCashPayment('no-existe'),
        throwsA(
          isA<ReservationCancellationException>().having(
            (e) => e.reason,
            'reason',
            ReservationCancellationError.notFound,
          ),
        ),
      );
    });
  });

  group('OwnerBookingController.operationalSummary', () {
    test('total/activeOrUpcoming/pendingPayment coinciden con un conteo '
        'manual de las reservas cacheadas', () async {
      final controller = OwnerBookingController();
      await controller.loadReservations();

      final all = controller.ownedReservations;
      final expectedActiveOrUpcoming = all
          .where(
            (r) =>
                r.status == ReservationStatus.active ||
                r.status == ReservationStatus.upcoming,
          )
          .length;
      final expectedPending = all
          .where((r) => r.status == ReservationStatus.pending)
          .length;

      final summary = controller.operationalSummary();

      expect(summary['total'], all.length);
      expect(summary['activeOrUpcoming'], expectedActiveOrUpcoming);
      expect(summary['pendingPayment'], expectedPending);
    });

    test('se puede acotar a un solo motel', () async {
      final controller = OwnerBookingController();
      await controller.loadReservations();

      final motelTwo = controller.ownedReservations
          .where((r) => r.motelId == '2')
          .toList();
      final expectedTotal = motelTwo.length;
      final expectedActiveOrUpcoming = motelTwo
          .where(
            (r) =>
                r.status == ReservationStatus.active ||
                r.status == ReservationStatus.upcoming,
          )
          .length;

      final summary = controller.operationalSummary(motelId: '2');

      expect(summary['total'], expectedTotal);
      expect(summary['activeOrUpcoming'], expectedActiveOrUpcoming);
    });
  });
}
