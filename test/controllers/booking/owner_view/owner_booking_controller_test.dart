import 'package:flutter_test/flutter_test.dart';

import 'package:machuco/controllers/booking/owner_view/owner_booking_controller.dart';
import 'package:machuco/models/booking/booking.dart';
import 'package:machuco/repositories/booking/booking_repository.dart';
import 'package:machuco/service/booking/booking_service.dart';
import 'package:machuco/service/booking/reservation_cancellation_notifier.dart';

void main() {
  _failureTests();
  _cancellationNotificationTests();

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

  group('OwnerBookingController.clientOptions', () {
    test('lista los clientes con reservas en los moteles del propietario y '
        'filtrar por uno devuelve solo su historial', () async {
      final controller = OwnerBookingController();
      await controller.loadReservations();

      final options = controller.clientOptions;
      expect(options, isNotEmpty);
      expect(options.map((o) => o.clientId).toSet().length, options.length);

      final first = options.first;
      final filtered = await controller.filteredReservations(
        clientId: first.clientId,
      );
      expect(filtered, isNotEmpty);
      expect(filtered.every((r) => r.guestId == first.clientId), isTrue);
      expect(
        filtered,
        await controller.reservationsForClient(
          controller.ownerId,
          first.clientId,
        ),
      );
    });

    test('un cliente ajeno a los moteles del propietario no devuelve '
        'reservas', () async {
      final controller = OwnerBookingController();

      expect(
        await controller.filteredReservations(clientId: 'cliente-ajeno'),
        isEmpty,
      );
    });
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
    test('transiciona una reserva pending a upcoming/active y deja la '
        'factura lista para emitirse', () async {
      final controller = OwnerBookingController();
      const reservationId = 'owner-reservation-003';

      final before = await controller.getById(reservationId);
      expect(before!.status, ReservationStatus.pending);
      final expectNextStatus = DateTime.now().isBefore(before.checkIn)
          ? ReservationStatus.upcoming
          : ReservationStatus.active;

      final paid = await controller.registerCashPayment(reservationId);

      final after = await controller.getById(reservationId);
      expect(after!.status, expectNextStatus);
      expect(after.paymentMethod, BookingService.cashPaymentMethod);
      expect(after.invoiceAccessStatus, isNot(InvoiceAccessStatus.pending));
      expect(after.invoiceAccessStatus, before.invoiceAccessStatus);
      expect(paid.id, reservationId);
      expect(paid.status, expectNextStatus);
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

class _FailingBookingRepository implements BookingRepository {
  @override
  Future<List<Reservation>> getAll() => Future.error(StateError('offline'));

  @override
  Future<Reservation?> getById(String id) => Future.error(StateError('x'));

  @override
  Future<Reservation?> findByRequestId(String requestId) =>
      Future.error(StateError('x'));

  @override
  Future<void> add(Reservation reservation) => Future.error(StateError('x'));

  @override
  Future<void> update(Reservation reservation) => Future.error(StateError('x'));
}

void _failureTests() {
  group('OwnerBookingController con repositorio que falla', () {
    test('loadReservations expone el error recuperable y reintenta', () async {
      final controller = OwnerBookingController(
        bookingService: BookingService(repository: _FailingBookingRepository()),
      );

      await controller.loadReservations();

      expect(controller.errorMessage, isNotNull);
      expect(controller.isLoading, isFalse);
      expect(controller.ownedReservations, isEmpty);

      // Retrying while the repository still fails keeps the error state.
      await controller.loadReservations();
      expect(controller.errorMessage, isNotNull);
    });
  });

  group('OwnerBookingController filter options', () {
    test(
      'room options are scoped by motel and reset when not belonging',
      () async {
        final controller = OwnerBookingController();
        await controller.loadReservations();

        final all = controller.roomOptionsFor();
        final motel1 = controller.roomOptionsFor(motelId: '1');
        final motel2 = controller.roomOptionsFor(motelId: '2');
        expect(motel1, isNotEmpty);
        expect(motel2, isNotEmpty);
        expect(motel1.length + motel2.length, all.length);

        final room2 = motel2.first.roomId;
        expect(controller.reconcileRoomSelection(room2, motelId: '2'), room2);
        expect(controller.reconcileRoomSelection(room2, motelId: '1'), isNull);
        expect(controller.reconcileRoomSelection(null, motelId: '1'), isNull);
      },
    );

    test('client options have one entry per guestId', () async {
      final controller = OwnerBookingController();
      await controller.loadReservations();

      final options = controller.clientOptionsFor();
      final ids = options.map((o) => o.clientId).toList();
      expect(ids.toSet().length, ids.length);
      final expected = controller.ownedReservations
          .map((r) => r.guestId)
          .where((id) => id.isNotEmpty)
          .toSet();
      expect(ids.toSet(), expected);

      final scoped = controller.clientOptionsFor(motelId: '1');
      final scopedIds = scoped.map((o) => o.clientId).toList();
      expect(scopedIds.toSet().length, scopedIds.length);
    });
  });
}

class _RecordingNotifier implements ReservationCancellationNotifier {
  _RecordingNotifier({this.result = true, this.error});

  final bool result;
  final Object? error;
  final List<Reservation> notified = [];

  @override
  Future<bool> notifyCancelled(Reservation reservation) async {
    notified.add(reservation);
    if (error != null) throw error!;
    return result;
  }
}

void _cancellationNotificationTests() {
  group('OwnerBookingController.cancelReservation notifica al cliente', () {
    OwnerBookingController controllerWith(_RecordingNotifier notifier) =>
        OwnerBookingController(
          bookingService: BookingService(
            repository: InMemoryBookingRepository(),
          ),
          cancellationNotifier: notifier,
        );

    test('envía la reserva cancelada, con su motivo, al notificador', () async {
      final notifier = _RecordingNotifier();
      final controller = controllerWith(notifier);

      await controller.cancelReservation(
        'owner-reservation-006',
        'Mantenimiento de la habitación',
      );

      expect(notifier.notified, hasLength(1));
      final sent = notifier.notified.single;
      expect(sent.id, 'owner-reservation-006');
      expect(sent.status, ReservationStatus.cancelled);
      expect(sent.cancellationReason, 'Mantenimiento de la habitación');
      expect(controller.lastCancellationNotified, isTrue);
    });

    test(
      'si la notificación falla, la reserva igual queda cancelada',
      () async {
        final notifier = _RecordingNotifier(
          error: StateError('sin base local'),
        );
        final controller = controllerWith(notifier);

        await controller.cancelReservation('owner-reservation-006', 'Motivo');

        final after = await controller.getById('owner-reservation-006');
        expect(after!.status, ReservationStatus.cancelled);
        expect(controller.lastCancellationNotified, isFalse);
      },
    );

    test('si el notificador no pudo avisar, lo informa', () async {
      final controller = controllerWith(_RecordingNotifier(result: false));

      await controller.cancelReservation('owner-reservation-006', 'Motivo');

      expect(controller.lastCancellationNotified, isFalse);
    });

    test('una cancelación rechazada no notifica a nadie', () async {
      final notifier = _RecordingNotifier();
      final controller = controllerWith(notifier);

      await expectLater(
        controller.cancelReservation('owner-reservation-001', 'Motivo'),
        throwsA(isA<ReservationCancellationException>()),
      );

      expect(notifier.notified, isEmpty);
    });
  });
}
