import 'package:flutter_test/flutter_test.dart';

import 'package:machuco/controllers/booking/client_view/client_booking_controller.dart';
import 'package:machuco/models/booking/booking.dart';
import 'package:machuco/repositories/booking/booking_repository.dart';
import 'package:machuco/service/booking/booking_service.dart';

void main() {
  final now = DateTime.now();

  group('ClientBookingController.isSlotAvailable', () {
    test(
      'rechaza un rango donde la salida no es posterior a la entrada',
      () async {
        final controller = ClientBookingController();
        await controller.refresh();

        final available = controller.isSlotAvailable(
          'room-101',
          now.add(const Duration(hours: 5)),
          now.add(const Duration(hours: 4)),
        );

        expect(available, isFalse);
      },
    );

    test('bloquea un horario que se solapa con una reserva vigente', () async {
      final controller = ClientBookingController();
      await controller.refresh();

      // 'room-101' tiene una reserva activa de seed entre now-1h y now+2h.
      final available = controller.isSlotAvailable(
        'room-101',
        now.add(const Duration(hours: 1)),
        now.add(const Duration(hours: 1, minutes: 30)),
      );

      expect(available, isFalse);
    });

    test(
      'libera el horario apenas termina el margen de 1 hora de preparación',
      () async {
        final controller = ClientBookingController();
        await controller.refresh();

        // La reserva activa de 'room-101' termina en now+2h; el margen de
        // preparación de 1h la bloquea hasta now+3h. Se deja un colchón de
        // unos minutos a cada lado del límite exacto para que la prueba no
        // sea sensible al pequeño desfase entre el `now` de esta prueba y
        // el `now` interno con el que el controlador siembra sus datos.
        final stillBlocked = controller.isSlotAvailable(
          'room-101',
          now.add(const Duration(hours: 2, minutes: 50)),
          now.add(const Duration(hours: 4)),
        );
        final available = controller.isSlotAvailable(
          'room-101',
          now.add(const Duration(hours: 3, minutes: 10)),
          now.add(const Duration(hours: 4)),
        );

        expect(stillBlocked, isFalse);
        expect(available, isTrue);
      },
    );

    test('una reserva cancelada no bloquea su propio horario', () async {
      final controller = ClientBookingController();
      await controller.refresh();

      // 'room-201' solo tiene la reserva de seed cancelada.
      final available = controller.isSlotAvailable(
        'room-201',
        now.add(const Duration(days: -3, hours: -2)),
        now.add(const Duration(days: -3)),
      );

      expect(available, isTrue);
    });

    test(
      'excludingReservationId ignora el solapamiento consigo misma',
      () async {
        final controller = ClientBookingController();
        await controller.refresh();

        final blockedWithoutExcluding = controller.isSlotAvailable(
          'room-101',
          now.add(const Duration(hours: -1)),
          now.add(const Duration(hours: 2)),
        );
        final availableExcludingItself = controller.isSlotAvailable(
          'room-101',
          now.add(const Duration(hours: -1)),
          now.add(const Duration(hours: 2)),
          excludingReservationId: 'reservation-seed-active',
        );

        expect(blockedWithoutExcluding, isFalse);
        expect(availableExcludingItself, isTrue);
      },
    );

    test(
      'respeta franjas externas bloqueadas y su margen de preparación',
      () async {
        final controller = ClientBookingController();
        await controller.refresh();
        final externalBlocked = [
          BlockedRange(
            now.add(const Duration(hours: 10)),
            now.add(const Duration(hours: 12)),
          ),
        ];

        final overlapping = controller.isSlotAvailable(
          'room-999-libre',
          now.add(const Duration(hours: 12, minutes: 30)),
          now.add(const Duration(hours: 13)),
          externalBlocked: externalBlocked,
        );
        final afterBuffer = controller.isSlotAvailable(
          'room-999-libre',
          now.add(const Duration(hours: 13)),
          now.add(const Duration(hours: 14)),
          externalBlocked: externalBlocked,
        );

        expect(overlapping, isFalse);
        expect(afterBuffer, isTrue);
      },
    );
  });

  group('ClientBookingController.explainBlockedSlot', () {
    test(
      'explica el bloqueo mencionando la hora hasta la que está ocupado',
      () async {
        final controller = ClientBookingController();
        await controller.refresh();

        final explanation = controller.explainBlockedSlot(
          'room-101',
          now.add(const Duration(hours: 1)),
          now.add(const Duration(hours: 1, minutes: 30)),
        );

        expect(explanation, contains('ocupado hasta'));
        expect(explanation, contains('preparación'));
      },
    );

    test(
      'da un mensaje genérico si el bloqueo viene de una franja externa',
      () async {
        final controller = ClientBookingController();
        await controller.refresh();
        final externalBlocked = [
          BlockedRange(
            now.add(const Duration(hours: 20)),
            now.add(const Duration(hours: 21)),
          ),
        ];

        final explanation = controller.explainBlockedSlot(
          'room-999-libre',
          now.add(const Duration(hours: 20, minutes: 30)),
          now.add(const Duration(hours: 21, minutes: 30)),
          externalBlocked: externalBlocked,
        );

        expect(explanation, contains('ocupado hasta'));
      },
    );
  });

  group('ClientBookingController.createReservation — cálculo de costos', () {
    test('el total combina habitación, servicios y productos', () async {
      final controller = ClientBookingController();
      await controller.refresh();

      final result = await controller.createReservation(
        requestId: 'req-cost-calc-1',
        motelId: 'motel-cost-test',
        motelName: 'Motel Prueba',
        roomId: 'room-cost-test-1',
        roomName: 'Suite Prueba',
        roomNumber: '900',
        checkIn: now.add(const Duration(days: 10)),
        checkOut: now.add(const Duration(days: 10, hours: 4)),
        stayMode: StayMode.dateWithHourBlock,
        guestCount: 2,
        services: const [
          ReservationLineItem(
            id: 'service-desayuno',
            name: 'Desayuno',
            unitPrice: 20000,
          ),
        ],
        products: const [
          ReservationLineItem(
            id: 'product-agua',
            name: 'Agua',
            unitPrice: 5000,
            quantity: 2,
          ),
        ],
        roomTotal: 100000,
      );

      expect(result.isSuccess, isTrue);
      final reservation = result.reservation!;
      expect(reservation.roomTotal, 100000);
      expect(reservation.servicesTotal, 20000);
      expect(reservation.productsTotal, 10000);
      expect(reservation.total, 130000);
      expect(reservation.status, ReservationStatus.pending);
      expect(controller.getById(reservation.id), isNotNull);
    });
  });

  group('ClientBookingController.createReservation — concurrencia e '
      'interrupción de red', () {
    test(
      'aborta la creación si la disponibilidad se pierde por concurrencia',
      () async {
        final controller = ClientBookingController();
        await controller.refresh();

        final result = await controller.createReservation(
          requestId: 'req-concurrency-1',
          motelId: 'motel-concurrency-test',
          motelName: 'Motel Prueba',
          roomId: 'room-concurrency-test-1',
          roomName: 'Suite Prueba',
          roomNumber: '901',
          checkIn: now.add(const Duration(days: 11)),
          checkOut: now.add(const Duration(days: 11, hours: 4)),
          stayMode: StayMode.dateWithHourBlock,
          guestCount: 2,
          services: const [],
          products: const [],
          roomTotal: 100000,
          simulateConcurrentConflict: true,
        );

        expect(result.isSuccess, isFalse);
        expect(result.outcome, CreateReservationOutcome.conflict);
        expect(
          controller.reservations.where(
            (r) => r.requestId == 'req-concurrency-1',
          ),
          isEmpty,
        );
      },
    );

    test('una interrupción de red no crea la reserva, y el reintento con el '
        'mismo requestId sí la crea sin duplicarla', () async {
      final controller = ClientBookingController();
      await controller.refresh();
      const requestId = 'req-network-retry-1';

      final firstAttempt = await controller.createReservation(
        requestId: requestId,
        motelId: 'motel-network-test',
        motelName: 'Motel Prueba',
        roomId: 'room-network-test-1',
        roomName: 'Suite Prueba',
        roomNumber: '902',
        checkIn: now.add(const Duration(days: 12)),
        checkOut: now.add(const Duration(days: 12, hours: 4)),
        stayMode: StayMode.dateWithHourBlock,
        guestCount: 2,
        services: const [],
        products: const [],
        roomTotal: 90000,
        simulateNetworkFailure: true,
      );

      expect(firstAttempt.outcome, CreateReservationOutcome.networkError);
      expect(
        controller.reservations.where((r) => r.requestId == requestId),
        isEmpty,
      );

      final retry = await controller.createReservation(
        requestId: requestId,
        motelId: 'motel-network-test',
        motelName: 'Motel Prueba',
        roomId: 'room-network-test-1',
        roomName: 'Suite Prueba',
        roomNumber: '902',
        checkIn: now.add(const Duration(days: 12)),
        checkOut: now.add(const Duration(days: 12, hours: 4)),
        stayMode: StayMode.dateWithHourBlock,
        guestCount: 2,
        services: const [],
        products: const [],
        roomTotal: 90000,
        simulateNetworkFailure: true,
      );

      expect(retry.isSuccess, isTrue);
      expect(
        controller.reservations.where((r) => r.requestId == requestId).length,
        1,
      );

      final secondRetry = await controller.createReservation(
        requestId: requestId,
        motelId: 'motel-network-test',
        motelName: 'Motel Prueba',
        roomId: 'room-network-test-1',
        roomName: 'Suite Prueba',
        roomNumber: '902',
        checkIn: now.add(const Duration(days: 12)),
        checkOut: now.add(const Duration(days: 12, hours: 4)),
        stayMode: StayMode.dateWithHourBlock,
        guestCount: 2,
        services: const [],
        products: const [],
        roomTotal: 90000,
      );

      expect(secondRetry.isSuccess, isTrue);
      expect(secondRetry.reservation!.id, retry.reservation!.id);
      expect(
        controller.reservations.where((r) => r.requestId == requestId).length,
        1,
        reason: 'El reintento idempotente no debe duplicar la reserva.',
      );
    });
  });

  group('ClientBookingController — expiración de reservas pending', () {
    test('una reserva recién creada tiene ~15 minutos restantes antes de '
        'expirar', () async {
      final controller = ClientBookingController();
      await controller.refresh();

      final result = await controller.createReservation(
        requestId: 'req-remaining-time-1',
        motelId: 'motel-remaining-test',
        motelName: 'Motel Prueba',
        roomId: 'room-remaining-test-1',
        roomName: 'Suite Prueba',
        roomNumber: '903',
        checkIn: now.add(const Duration(days: 13)),
        checkOut: now.add(const Duration(days: 13, hours: 4)),
        stayMode: StayMode.dateWithHourBlock,
        guestCount: 2,
        services: const [],
        products: const [],
        roomTotal: 80000,
      );

      final remaining = controller.remainingPendingTime(result.reservation!.id);

      expect(remaining, isNotNull);
      expect(remaining!.inSeconds, inInclusiveRange(14 * 60, 15 * 60));

      // checkExpirations() no debe cancelar una reserva recién creada.
      controller.checkExpirations();
      expect(
        controller.getById(result.reservation!.id)!.status,
        ReservationStatus.pending,
      );
    });

    test(
      'remainingPendingTime es null para una reserva que no está pending',
      () async {
        final controller = ClientBookingController();
        await controller.refresh();

        final remaining = controller.remainingPendingTime(
          'reservation-seed-active',
        );

        expect(remaining, isNull);
      },
    );

    group('con reloj inyectado', () {
      late DateTime clock;
      late ClientBookingController controller;

      setUp(() {
        clock = DateTime(2026, 3, 10, 12);
        final repository = InMemoryBookingRepository(
          initial: [
            Reservation(
              id: 'pending-1',
              requestId: 'req-pending-1',
              motelId: '1',
              motelName: 'Motel Prueba',
              roomId: 'room-clock',
              roomName: 'Suite Reloj',
              roomNumber: '1',
              checkIn: DateTime(2026, 3, 11, 14),
              checkOut: DateTime(2026, 3, 11, 18),
              stayMode: StayMode.dateTimeRange,
              guestCount: 2,
              services: const [],
              products: const [],
              roomTotal: 100000,
              total: 100000,
              status: ReservationStatus.pending,
              createdAt: clock,
              guestId: ClientBookingController.demoUserId,
            ),
          ],
        );
        controller = ClientBookingController(
          bookingService: BookingService(
            repository: repository,
            now: () => clock,
          ),
        );
      });

      tearDown(() => controller.dispose());

      test('la reserva sigue pending un segundo antes de los 15 minutos, '
          'y se cancela y libera la franja justo a los 15', () async {
        await controller.refresh();

        clock = DateTime(2026, 3, 10, 12, 14, 59);
        controller.checkExpirations();
        expect(
          controller.getById('pending-1')!.status,
          ReservationStatus.pending,
        );
        expect(
          controller.remainingPendingTime('pending-1'),
          const Duration(seconds: 1),
        );
        expect(
          controller.isSlotAvailable(
            'room-clock',
            DateTime(2026, 3, 11, 14),
            DateTime(2026, 3, 11, 18),
          ),
          isFalse,
        );

        clock = DateTime(2026, 3, 10, 12, 15);
        controller.checkExpirations();
        expect(
          controller.getById('pending-1')!.status,
          ReservationStatus.cancelled,
        );
        expect(controller.remainingPendingTime('pending-1'), isNull);
        expect(
          controller.isSlotAvailable(
            'room-clock',
            DateTime(2026, 3, 11, 14),
            DateTime(2026, 3, 11, 18),
          ),
          isTrue,
        );
      });

      test('el temporizador del controlador expira la reserva y avisa a '
          'los oyentes', () async {
        await controller.refresh();
        var notifications = 0;
        controller.addListener(() => notifications++);

        controller.startExpirationWatch(
          interval: const Duration(milliseconds: 10),
        );
        clock = DateTime(2026, 3, 10, 12, 15);
        await Future<void>.delayed(const Duration(milliseconds: 60));

        expect(notifications, greaterThan(0));
        expect(
          controller.getById('pending-1')!.status,
          ReservationStatus.cancelled,
        );
      });
    });
  });

  group('ClientBookingController.confirmPayment', () {
    test('mueve una reserva pending con check-in futuro a upcoming', () async {
      final controller = ClientBookingController();
      await controller.refresh();

      final confirmed = await controller.confirmPayment(
        'reservation-seed-pending',
      );

      expect(confirmed, isTrue);
      expect(
        controller.getById('reservation-seed-pending')!.status,
        ReservationStatus.upcoming,
      );
    });

    test(
      'mueve una reserva pending con check-in ya iniciado a active',
      () async {
        final controller = ClientBookingController();
        await controller.refresh();

        final result = await controller.createReservation(
          requestId: 'req-confirm-active-1',
          motelId: 'motel-confirm-test',
          motelName: 'Motel Prueba',
          roomId: 'room-confirm-test-1',
          roomName: 'Suite Prueba',
          roomNumber: '904',
          checkIn: now.subtract(const Duration(minutes: 30)),
          checkOut: now.add(const Duration(minutes: 30)),
          stayMode: StayMode.dateWithHourBlock,
          guestCount: 2,
          services: const [],
          products: const [],
          roomTotal: 70000,
        );

        final confirmed = await controller.confirmPayment(
          result.reservation!.id,
        );

        expect(confirmed, isTrue);
        expect(
          controller.getById(result.reservation!.id)!.status,
          ReservationStatus.active,
        );
      },
    );

    test('devuelve false para un id inexistente', () async {
      final controller = ClientBookingController();
      await controller.refresh();

      final confirmed = await controller.confirmPayment('no-existe');

      expect(confirmed, isFalse);
    });

    test('devuelve false si la reserva ya no está pending', () async {
      final controller = ClientBookingController();
      await controller.refresh();

      final confirmed = await controller.confirmPayment(
        'reservation-seed-active',
      );

      expect(confirmed, isFalse);
    });
  });

  group('ClientBookingController.cancelReservation', () {
    test(
      'rechaza un motivo vacío y no cambia el estado de la reserva',
      () async {
        final controller = ClientBookingController();
        await controller.refresh();

        final result = await controller.createReservation(
          requestId: 'req-cancel-empty-reason-1',
          motelId: 'motel-cancel-test',
          motelName: 'Motel Prueba',
          roomId: 'room-cancel-test-1',
          roomName: 'Suite Prueba',
          roomNumber: '910',
          checkIn: now.add(const Duration(days: 20)),
          checkOut: now.add(const Duration(days: 20, hours: 4)),
          stayMode: StayMode.dateWithHourBlock,
          guestCount: 2,
          services: const [],
          products: const [],
          roomTotal: 90000,
        );
        final reservationId = result.reservation!.id;

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

        final after = controller.getById(reservationId);
        expect(after!.status, ReservationStatus.pending);
        expect(after.cancellationReason, isNull);
      },
    );

    test('cancela una reserva pending con motivo válido', () async {
      final controller = ClientBookingController();
      await controller.refresh();

      final result = await controller.createReservation(
        requestId: 'req-cancel-pending-1',
        motelId: 'motel-cancel-test',
        motelName: 'Motel Prueba',
        roomId: 'room-cancel-test-2',
        roomName: 'Suite Prueba',
        roomNumber: '911',
        checkIn: now.add(const Duration(days: 21)),
        checkOut: now.add(const Duration(days: 21, hours: 4)),
        stayMode: StayMode.dateWithHourBlock,
        guestCount: 2,
        services: const [],
        products: const [],
        roomTotal: 90000,
      );
      final reservationId = result.reservation!.id;

      await controller.cancelReservation(
        reservationId,
        'El cliente ya no puede asistir.',
      );

      final after = controller.getById(reservationId);
      expect(after!.status, ReservationStatus.cancelled);
      expect(after.cancellationReason, 'El cliente ya no puede asistir.');
    });

    test('cancela una reserva upcoming con motivo válido', () async {
      final controller = ClientBookingController();
      await controller.refresh();

      final result = await controller.createReservation(
        requestId: 'req-cancel-upcoming-1',
        motelId: 'motel-cancel-test',
        motelName: 'Motel Prueba',
        roomId: 'room-cancel-test-3',
        roomName: 'Suite Prueba',
        roomNumber: '912',
        checkIn: now.add(const Duration(days: 22)),
        checkOut: now.add(const Duration(days: 22, hours: 4)),
        stayMode: StayMode.dateWithHourBlock,
        guestCount: 2,
        services: const [],
        products: const [],
        roomTotal: 90000,
      );
      final reservationId = result.reservation!.id;
      await controller.confirmPayment(reservationId);
      expect(
        controller.getById(reservationId)!.status,
        ReservationStatus.upcoming,
      );

      await controller.cancelReservation(reservationId, 'Reprogramación');

      final after = controller.getById(reservationId);
      expect(after!.status, ReservationStatus.cancelled);
      expect(after.cancellationReason, 'Reprogramación');
    });

    test('rechaza cancelar reservas en estados no cancelables (active, '
        'completed, cancelled)', () async {
      final controller = ClientBookingController();
      await controller.refresh();

      for (final reservationId in [
        'reservation-seed-active',
        'reservation-seed-completed',
        'reservation-seed-cancelled',
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
      final controller = ClientBookingController();
      await controller.refresh();

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
  group('ClientBookingController.createReservationForType', () {
    final clock = DateTime(2026, 3, 10, 12);
    DateTime at(int day, int hour) => DateTime(2026, 3, day, hour);

    const roomA = RoomCandidate(id: 'room-a', name: 'Suite', number: '1');
    const roomOff = RoomCandidate(
      id: 'room-off',
      name: 'Suite',
      number: '2',
      isActive: false,
    );

    late InMemoryBookingRepository repository;
    late ClientBookingController controller;

    setUp(() {
      repository = InMemoryBookingRepository(initial: const []);
      controller = ClientBookingController(
        bookingService: BookingService(
          repository: repository,
          now: () => clock,
        ),
      );
    });

    tearDown(() => controller.dispose());

    Future<CreateReservationResult> reserve(
      List<RoomCandidate> rooms, {
      String requestId = 'req-1',
      bool simulateNetworkFailure = false,
    }) => controller.createReservationForType(
      requestId: requestId,
      motelId: 'm1',
      motelName: 'Motel m1',
      rooms: rooms,
      checkIn: at(11, 14),
      checkOut: at(11, 18),
      stayMode: StayMode.dateTimeRange,
      guestCount: 2,
      services: const [],
      products: const [],
      roomTotal: 100000,
      simulateNetworkFailure: simulateNetworkFailure,
    );

    test('asigna una habitación activa y crea la reserva pending', () async {
      final result = await reserve([roomOff, roomA]);

      expect(result.isSuccess, isTrue);
      expect(result.reservation!.roomId, 'room-a');
      expect(result.reservation!.status, ReservationStatus.pending);
    });

    test('sin unidades activas rechaza con un resultado propio', () async {
      final result = await reserve([roomOff]);

      expect(result.outcome, CreateReservationOutcome.noActiveUnits);
      expect(result.message, BookingService.noActiveUnitsMessage);
      expect(await repository.getAll(), isEmpty);
    });

    test('pierde la última habitación por concurrencia: conflicto con '
        'mensaje que sugiere cambiar fechas o tipo', () async {
      await reserve([roomA], requestId: 'req-winner');

      final result = await reserve([roomA], requestId: 'req-loser');

      expect(result.outcome, CreateReservationOutcome.conflict);
      expect(result.message, contains('acaban de ser ocupados'));
      expect(result.message, contains('tipo de habitación'));
      expect((await repository.getAll()).length, 1);
    });

    test('un fallo de red se puede reintentar con el mismo requestId sin '
        'duplicar la reserva', () async {
      final first = await reserve(
        [roomA],
        requestId: 'req-net-type',
        simulateNetworkFailure: true,
      );
      expect(first.outcome, CreateReservationOutcome.networkError);
      expect(await repository.getAll(), isEmpty);

      final retry = await reserve(
        [roomA],
        requestId: 'req-net-type',
        simulateNetworkFailure: true,
      );
      final again = await reserve([roomA], requestId: 'req-net-type');

      expect(retry.isSuccess, isTrue);
      expect(again.reservation!.id, retry.reservation!.id);
      expect((await repository.getAll()).length, 1);
    });

    test('un error inesperado del repositorio es recuperable', () async {
      final failing = ClientBookingController(
        bookingService: BookingService(
          repository: _FailingBookingRepository(),
          now: () => clock,
        ),
      );
      addTearDown(failing.dispose);

      final result = await failing.createReservationForType(
        requestId: 'req-x',
        motelId: 'm1',
        motelName: 'Motel m1',
        rooms: const [roomA],
        checkIn: at(11, 14),
        checkOut: at(11, 18),
        stayMode: StayMode.dateTimeRange,
        guestCount: 2,
        services: const [],
        products: const [],
        roomTotal: 100000,
      );

      expect(result.outcome, CreateReservationOutcome.networkError);
    });

    test('typeScheduleError valida el tipo de habitación completo', () async {
      await reserve([roomA], requestId: 'req-busy');
      await controller.refresh();

      expect(
        controller.typeScheduleError([roomOff], at(12, 14), at(12, 18)),
        BookingService.noActiveUnitsMessage,
      );
      expect(
        controller.typeScheduleError([roomA], at(11, 14), at(11, 18)),
        BookingService.slotTakenMessage,
      );
      expect(
        controller.typeScheduleError([roomA], at(12, 14), at(12, 18)),
        isNull,
      );
    });
  });

  group('ClientBookingController.loadReservations', () {
    test(
      'si el repositorio falla expone un error y no un listado vacío',
      () async {
        final controller = ClientBookingController(
          bookingService: BookingService(
            repository: _FailingBookingRepository(),
          ),
        );
        addTearDown(controller.dispose);

        await controller.loadReservations();

        expect(controller.errorMessage, isNotNull);
        expect(controller.isLoading, isFalse);
      },
    );
  });
}

class _FailingBookingRepository implements BookingRepository {
  @override
  Future<List<Reservation>> getAll() => Future.error(StateError('offline'));

  @override
  Future<Reservation?> getById(String id) => Future.error(StateError('x'));

  @override
  Future<Reservation?> findByRequestId(String requestId) =>
      Future.error(StateError('offline'));

  @override
  Future<void> add(Reservation reservation) =>
      Future.error(StateError('offline'));

  @override
  Future<void> update(Reservation reservation) =>
      Future.error(StateError('offline'));
}
