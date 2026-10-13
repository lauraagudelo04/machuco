import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:machuco/models/booking/booking.dart';
import 'package:machuco/repositories/booking/booking_repository.dart';
import 'package:machuco/service/booking/booking_service.dart';
import 'package:machuco/utils/booking/reservation_cancellation_exception.dart';
import 'package:machuco/utils/booking/reservation_transition_exception.dart';

void main() {
  late DateTime clock;
  late InMemoryBookingRepository repository;
  late BookingService service;

  // Fixed reference instant: 10 March 2026, 12:00.
  DateTime at(int day, int hour, [int minute = 0]) =>
      DateTime(2026, 3, day, hour, minute);

  Reservation reservation({
    String id = 'r1',
    String roomId = 'room-a',
    DateTime? checkIn,
    DateTime? checkOut,
    ReservationStatus status = ReservationStatus.upcoming,
    DateTime? createdAt,
    int total = 100000,
    int? categoryId,
    String? paymentMethod,
    String motelId = 'm1',
  }) {
    return Reservation(
      id: id,
      requestId: 'req-$id',
      motelId: motelId,
      motelName: 'Motel $motelId',
      roomId: roomId,
      roomName: 'Suite',
      roomNumber: '1',
      checkIn: checkIn ?? at(10, 14),
      checkOut: checkOut ?? at(10, 18),
      stayMode: StayMode.dateTimeRange,
      guestCount: 2,
      services: const [],
      products: const [],
      roomTotal: total,
      total: total,
      status: status,
      createdAt: createdAt ?? at(10, 9),
      categoryId: categoryId,
      paymentMethod: paymentMethod,
    );
  }

  void seed(List<Reservation> reservations) {
    repository = InMemoryBookingRepository(initial: reservations);
    service = BookingService(repository: repository, now: () => clock);
  }

  setUp(() {
    clock = at(10, 12);
    seed(const []);
  });

  group('isSlotAvailable', () {
    // Existing reservation: 14:00-18:00 -> room blocked until 19:00.
    setUp(() => seed([reservation()]));

    Future<bool> available(
      DateTime start,
      DateTime end, {
      String roomId = 'room-a',
      String? excluding,
      bool roomIsActive = true,
      List<BlockedRange> external = const [],
    }) async => service.isSlotAvailable(
      await repository.getAll(),
      roomId,
      start,
      end,
      excludingReservationId: excluding,
      roomIsActive: roomIsActive,
      externalBlocked: external,
    );

    test('blocks a slot that overlaps an existing reservation', () async {
      expect(await available(at(10, 16), at(10, 20)), isFalse);
    });

    test('blocks during the 1 hour preparation buffer after it', () async {
      expect(await available(at(10, 18, 30), at(10, 20)), isFalse);
      expect(await available(at(10, 18, 59), at(10, 21)), isFalse);
    });

    test('frees the slot exactly when the buffer ends', () async {
      expect(await available(at(10, 19), at(10, 21)), isTrue);
    });

    test('keeps the buffer before the next reservation too', () async {
      // Ends at 13:00: exactly 1h before the 14:00 reservation -> allowed.
      expect(await available(at(10, 11), at(10, 13)), isTrue);
      // Ends at 13:01: less than 1h of preparation left -> blocked.
      expect(await available(at(10, 11), at(10, 13, 1)), isFalse);
    });

    test('other rooms are not affected', () async {
      expect(await available(at(10, 14), at(10, 18), roomId: 'room-b'), isTrue);
    });

    test('rejects an empty or inverted range', () async {
      expect(await available(at(10, 20), at(10, 20)), isFalse);
      expect(await available(at(10, 21), at(10, 20)), isFalse);
    });

    test('rejects an inactive room', () async {
      expect(
        await available(at(11, 10), at(11, 12), roomIsActive: false),
        isFalse,
      );
    });

    test('excludingReservationId ignores that reservation', () async {
      expect(await available(at(10, 14), at(10, 18), excluding: 'r1'), isTrue);
    });

    test('cancelled and completed reservations do not block', () async {
      for (final status in [
        ReservationStatus.cancelled,
        ReservationStatus.completed,
      ]) {
        seed([reservation(status: status)]);
        expect(
          await available(at(10, 14), at(10, 18)),
          isTrue,
          reason: '$status',
        );
      }
    });

    test('pending, upcoming and active reservations block', () async {
      for (final status in [
        ReservationStatus.pending,
        ReservationStatus.upcoming,
        ReservationStatus.active,
      ]) {
        seed([reservation(status: status, createdAt: clock)]);
        expect(
          await available(at(10, 14), at(10, 18)),
          isFalse,
          reason: '$status',
        );
      }
    });

    test('an expired pending reservation releases its slot', () async {
      seed([
        reservation(
          status: ReservationStatus.pending,
          createdAt: clock.subtract(const Duration(minutes: 15)),
        ),
      ]);
      expect(await available(at(10, 14), at(10, 18)), isTrue);
    });

    test('respects external blocked ranges and their buffer', () async {
      final external = [BlockedRange(at(12, 10), at(12, 12))];
      expect(
        await available(at(12, 12, 30), at(12, 14), external: external),
        isFalse,
      );
      expect(
        await available(at(12, 13), at(12, 15), external: external),
        isTrue,
      );
    });

    test('explainBlockedSlot says until when the room is busy', () async {
      final message = service.explainBlockedSlot(
        await repository.getAll(),
        'room-a',
        at(10, 15),
        at(10, 16),
      );
      expect(message, contains('ocupado hasta'));
      expect(message, contains('7:00 p. m.'));
    });
  });

  group('validateSchedule', () {
    test('requires the check-in to be in the future', () {
      expect(service.validateSchedule(at(10, 11), at(10, 13)), isNotNull);
      expect(service.validateSchedule(at(10, 12), at(10, 13)), isNull);
    });

    test('requires check-out after check-in', () {
      expect(service.validateSchedule(at(10, 14), at(10, 14)), isNotNull);
    });

    test('allows exactly 24 hours and rejects anything longer', () {
      expect(service.validateSchedule(at(10, 14), at(11, 14)), isNull);
      expect(service.validateSchedule(at(10, 14), at(11, 14, 1)), isNotNull);
    });
  });

  group('calculatePrice', () {
    test('bills each started hour and adds services and products', () {
      final price = service.calculatePrice(
        pricePerHour: 50000,
        checkIn: at(10, 14),
        checkOut: at(10, 16, 1),
        services: const [
          ReservationLineItem(id: 's', name: 'Jacuzzi', unitPrice: 20000),
        ],
        products: const [
          ReservationLineItem(
            id: 'p',
            name: 'Agua',
            unitPrice: 5000,
            quantity: 2,
          ),
        ],
      );

      expect(price.hours, 3);
      expect(price.roomTotal, 150000);
      expect(price.servicesTotal, 20000);
      expect(price.productsTotal, 10000);
      expect(price.total, 180000);
    });

    test('is zero for the room without a valid range', () {
      expect(service.calculatePrice(pricePerHour: 50000).hours, 0);
      expect(
        service
            .calculatePrice(
              pricePerHour: 50000,
              checkIn: at(10, 16),
              checkOut: at(10, 14),
            )
            .total,
        0,
      );
    });
  });

  group('createReservation', () {
    Future<Reservation> create({
      String requestId = 'req-new',
      DateTime? checkIn,
      DateTime? checkOut,
      String roomId = 'room-a',
      bool roomIsActive = true,
    }) => service.createReservation(
      requestId: requestId,
      motelId: 'm1',
      motelName: 'Motel m1',
      roomId: roomId,
      roomName: 'Suite',
      roomNumber: '1',
      checkIn: checkIn ?? at(11, 14),
      checkOut: checkOut ?? at(11, 18),
      stayMode: StayMode.dateTimeRange,
      guestCount: 2,
      services: const [
        ReservationLineItem(id: 's', name: 'Jacuzzi', unitPrice: 20000),
      ],
      products: const [],
      roomTotal: 200000,
      roomIsActive: roomIsActive,
    );

    test('creates a pending reservation with the total computed', () async {
      final created = await create();

      expect(created.status, ReservationStatus.pending);
      expect(created.total, 220000);
      expect(created.createdAt, clock);
      expect(await repository.getById(created.id), isNotNull);
    });

    test('is idempotent by requestId', () async {
      final first = await create();
      final second = await create();

      expect(second.id, first.id);
      expect((await repository.getAll()).length, 1);
    });

    test('concurrent calls with the same requestId create one', () async {
      final results = await Future.wait([create(), create()]);

      expect(results[0].id, results[1].id);
      expect((await repository.getAll()).length, 1);
    });

    test('same-microsecond creations get distinct ids', () async {
      final a = await create(requestId: 'req-a', roomId: 'room-a');
      final b = await create(requestId: 'req-b', roomId: 'room-b');

      expect(a.createdAt, b.createdAt);
      expect(a.id, isNot(b.id));
      expect((await repository.getAll()).length, 2);
    });

    test('throws when the slot is taken', () async {
      seed([reservation(checkIn: at(11, 14), checkOut: at(11, 18))]);

      await expectLater(create(), throwsA(isA<SlotUnavailableException>()));
      expect((await repository.getAll()).length, 1);
    });

    test('throws for an inactive room', () async {
      await expectLater(
        create(roomIsActive: false),
        throwsA(isA<SlotUnavailableException>()),
      );
    });

    test('throws for a stay over 24 hours', () async {
      await expectLater(
        create(checkIn: at(11, 14), checkOut: at(12, 15)),
        throwsA(isA<SlotUnavailableException>()),
      );
    });
  });

  group('pending expiration (15 minutes)', () {
    Reservation pending() => reservation(
      status: ReservationStatus.pending,
      createdAt: at(10, 12),
      checkIn: at(11, 14),
      checkOut: at(11, 18),
    );

    test('stays pending one second before the limit', () async {
      seed([pending()]);
      clock = at(10, 12, 14).add(const Duration(seconds: 59));

      expect(
        (await service.getReservation('r1'))!.status,
        ReservationStatus.pending,
      );
      expect(
        service.remainingPendingTime(pending()),
        const Duration(seconds: 1),
      );
    });

    test(
      'is cancelled exactly at 15 minutes and the change is stored',
      () async {
        seed([pending()]);
        clock = at(10, 12, 15);

        final resolved = await service.getReservation('r1');

        expect(resolved!.status, ReservationStatus.cancelled);
        expect(resolved.cancellationReason, isNotNull);
        expect(
          (await repository.getById('r1'))!.status,
          ReservationStatus.cancelled,
        );
        expect(service.remainingPendingTime(resolved), isNull);
      },
    );

    test('remaining time counts down from 15 minutes', () {
      expect(
        service.remainingPendingTime(pending()),
        BookingService.pendingPaymentTimeout,
      );
    });
  });

  group('time based transitions', () {
    test('upcoming becomes active when its check-in is reached', () async {
      seed([reservation(checkIn: at(10, 14), checkOut: at(10, 18))]);

      clock = at(10, 13, 59);
      expect(
        (await service.getReservation('r1'))!.status,
        ReservationStatus.upcoming,
      );

      clock = at(10, 14);
      expect(
        (await service.getReservation('r1'))!.status,
        ReservationStatus.active,
      );
    });

    test('active becomes completed at check-out time', () async {
      seed([
        reservation(
          status: ReservationStatus.active,
          checkIn: at(10, 10),
          checkOut: at(10, 14),
        ),
      ]);

      clock = at(10, 13, 59);
      expect(
        (await service.getReservation('r1'))!.status,
        ReservationStatus.active,
      );

      clock = at(10, 14);
      await service.syncStatuses();
      expect(
        (await repository.getById('r1'))!.status,
        ReservationStatus.completed,
      );
    });

    test('an upcoming reservation already over becomes completed', () async {
      seed([reservation(checkIn: at(10, 8), checkOut: at(10, 10))]);

      expect(
        (await service.getReservation('r1'))!.status,
        ReservationStatus.completed,
      );
    });

    test('cancelled and completed never change', () async {
      seed([
        reservation(id: 'c', status: ReservationStatus.cancelled),
        reservation(id: 'd', status: ReservationStatus.completed),
      ]);
      clock = at(20, 12);

      final all = await service.getReservations();
      expect(all.map((r) => r.status), [
        ReservationStatus.cancelled,
        ReservationStatus.completed,
      ]);
    });
  });

  group('confirmPayment', () {
    Reservation pending({DateTime? checkIn, DateTime? checkOut}) => reservation(
      status: ReservationStatus.pending,
      createdAt: at(10, 11, 55),
      checkIn: checkIn ?? at(11, 14),
      checkOut: checkOut ?? at(11, 18),
    );

    test('moves a future pending reservation to upcoming', () async {
      seed([pending()]);

      final paid = await service.confirmPayment('r1');

      expect(paid.status, ReservationStatus.upcoming);
      expect(paid.paymentMethod, BookingService.defaultPaymentMethod);
      expect(
        (await repository.getById('r1'))!.status,
        ReservationStatus.upcoming,
      );
    });

    test('moves a pending reservation already started to active', () async {
      seed([pending(checkIn: at(10, 11, 30), checkOut: at(10, 14))]);

      final paid = await service.confirmPayment('r1', paymentMethod: 'Nequi');

      expect(paid.status, ReservationStatus.active);
      expect(paid.paymentMethod, 'Nequi');
    });

    test('rejects reservations that are not pending', () async {
      for (final status in [
        ReservationStatus.upcoming,
        ReservationStatus.active,
        ReservationStatus.completed,
        ReservationStatus.cancelled,
      ]) {
        seed([
          reservation(
            status: status,
            checkIn: at(10, 10),
            checkOut: at(10, 18),
          ),
        ]);
        await expectLater(
          service.confirmPayment('r1'),
          throwsA(isA<ReservationTransitionException>()),
          reason: '$status',
        );
      }
    });

    test('rejects a reservation whose 15 minutes already expired', () async {
      seed([pending()]);
      clock = at(10, 12, 10);

      await expectLater(
        service.confirmPayment('r1'),
        throwsA(
          isA<ReservationTransitionException>().having(
            (e) => e.from,
            'from',
            ReservationStatus.cancelled,
          ),
        ),
      );
    });

    test('throws notFound for an unknown id', () async {
      await expectLater(
        service.confirmPayment('missing'),
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

  group('registerCashPayment', () {
    test('pays a pending reservation and marks the invoice pending', () async {
      seed([
        reservation(
          status: ReservationStatus.pending,
          createdAt: at(10, 11, 55),
          checkIn: at(11, 14),
          checkOut: at(11, 18),
        ),
      ]);

      final paid = await service.registerCashPayment('r1');

      expect(paid.status, ReservationStatus.upcoming);
      expect(paid.paymentMethod, BookingService.cashPaymentMethod);
      expect(paid.invoiceAccessStatus, InvoiceAccessStatus.pending);
    });

    test(
      'keeps the status and method of an already paid reservation',
      () async {
        seed([
          reservation(
            status: ReservationStatus.active,
            checkIn: at(10, 10),
            checkOut: at(10, 18),
            paymentMethod: 'Tarjeta',
          ),
        ]);

        final paid = await service.registerCashPayment('r1');

        expect(paid.status, ReservationStatus.active);
        expect(paid.paymentMethod, 'Tarjeta');
        expect(paid.invoiceAccessStatus, InvoiceAccessStatus.pending);
      },
    );

    test('rejects cancelled and completed reservations', () async {
      for (final status in [
        ReservationStatus.cancelled,
        ReservationStatus.completed,
      ]) {
        seed([reservation(status: status)]);
        await expectLater(
          service.registerCashPayment('r1'),
          throwsA(isA<ReservationTransitionException>()),
          reason: '$status',
        );
      }
    });

    test('throws notFound for an unknown id', () async {
      await expectLater(
        service.registerCashPayment('missing'),
        throwsA(isA<ReservationCancellationException>()),
      );
    });
  });

  group('cancelReservation', () {
    test('cancels pending and upcoming reservations with a reason', () async {
      for (final status in [
        ReservationStatus.pending,
        ReservationStatus.upcoming,
      ]) {
        seed([
          reservation(
            status: status,
            createdAt: at(10, 11, 55),
            checkIn: at(11, 14),
            checkOut: at(11, 18),
          ),
        ]);

        final cancelled = await service.cancelReservation('r1', '  Cambio  ');

        expect(cancelled.status, ReservationStatus.cancelled);
        expect(cancelled.cancellationReason, 'Cambio');
        expect(
          (await repository.getById('r1'))!.status,
          ReservationStatus.cancelled,
        );
      }
    });

    test('rejects active, completed and cancelled reservations', () async {
      for (final status in [
        ReservationStatus.active,
        ReservationStatus.completed,
        ReservationStatus.cancelled,
      ]) {
        seed([
          reservation(
            status: status,
            checkIn: at(10, 10),
            checkOut: at(10, 18),
          ),
        ]);
        await expectLater(
          service.cancelReservation('r1', 'Motivo'),
          throwsA(
            isA<ReservationCancellationException>().having(
              (e) => e.reason,
              'reason',
              ReservationCancellationError.invalidStatus,
            ),
          ),
          reason: '$status',
        );
      }
    });

    test(
      'requires a non blank reason and leaves the state untouched',
      () async {
        seed([reservation(checkIn: at(11, 14), checkOut: at(11, 18))]);

        await expectLater(
          service.cancelReservation('r1', '   '),
          throwsA(
            isA<ReservationCancellationException>().having(
              (e) => e.reason,
              'reason',
              ReservationCancellationError.reasonRequired,
            ),
          ),
        );
        expect(
          (await repository.getById('r1'))!.status,
          ReservationStatus.upcoming,
        );
      },
    );

    test('throws notFound for an unknown id', () async {
      await expectLater(
        service.cancelReservation('missing', 'Motivo'),
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

  group('filters, sorting and statistics', () {
    late List<Reservation> sample;

    setUp(() {
      sample = [
        reservation(
          id: 'a',
          motelId: 'm1',
          total: 100,
          categoryId: 1,
          checkIn: at(10, 14),
          createdAt: at(1, 9),
        ),
        reservation(
          id: 'b',
          motelId: 'm2',
          total: 300,
          categoryId: 2,
          status: ReservationStatus.cancelled,
          checkIn: at(12, 14),
          createdAt: at(3, 9),
        ),
        reservation(
          id: 'c',
          motelId: 'm1',
          total: 200,
          categoryId: 2,
          status: ReservationStatus.completed,
          paymentMethod: 'Efectivo',
          checkIn: at(8, 14),
          createdAt: at(2, 9),
        ),
      ];
    });

    test('filters combine and ignore empty criteria', () {
      expect(
        service
            .filterReservations(sample, motelId: 'm1', categoryId: 2)
            .map((r) => r.id),
        ['c'],
      );
      expect(service.filterReservations(sample, motelId: '').length, 3);
      expect(
        service.filterReservations(sample, motelIds: {'m2'}).single.id,
        'b',
      );
      expect(
        service
            .filterReservations(sample, status: ReservationStatus.cancelled)
            .single
            .id,
        'b',
      );
    });

    test('sorts by the chosen field in both directions', () {
      expect(
        service
            .sortReservations(sample, field: ReservationSortField.total)
            .map((r) => r.id),
        ['b', 'c', 'a'],
      );
      expect(
        service
            .sortReservations(
              sample,
              field: ReservationSortField.checkIn,
              descending: false,
            )
            .map((r) => r.id),
        ['c', 'a', 'b'],
      );
    });

    test('operationalSummary counts statuses', () {
      final summary = service.operationalSummary(sample);
      expect(summary.total, 3);
      expect(summary.activeOrUpcoming, 1);
      expect(summary.pendingPayment, 0);
    });

    test('KPIs only count paid reservations as revenue', () {
      final kpis = service.computeKpis(sample, roomCount: 10);

      expect(kpis.totalReservations, 3);
      expect(kpis.activeReservations, 1);
      expect(kpis.cancelledReservations, 1);
      expect(kpis.totalRevenue, 300);
      expect(kpis.monthlyAverage, 3 / 12);
      expect(kpis.averagePerDay, 3 / 365);
      expect(service.computeKpis(sample, roomCount: 0).occupancyRate, 0);
    });

    test('evolution returns 12 months and filters by status', () {
      final all = service.reservationsEvolution(sample);
      expect(all, hasLength(12));
      expect(all.last.month, DateTime(2026, 3));
      expect(all.fold<int>(0, (sum, p) => sum + p.count), 3);

      final cancelled = service.reservationsEvolution(
        sample,
        status: ReservationStatus.cancelled,
      );
      expect(cancelled.fold<int>(0, (sum, p) => sum + p.count), 1);
    });

    test('payment breakdown groups paid reservations by method', () {
      final breakdown = service.paymentBreakdown(sample);

      expect(breakdown.totalAmount, 300);
      expect(breakdown.totalCount, 2);
      expect(breakdown.byMethod.first.method, 'Efectivo');
      expect(breakdown.byMethod.first.total, 200);
      expect(breakdown.byMethod.last.method, 'Sin registrar');
    });
  });
  group('room type assignment', () {
    const roomA = RoomCandidate(id: 'room-a', name: 'Suite', number: '1');
    const roomB = RoomCandidate(id: 'room-b', name: 'Suite', number: '2');
    const roomOff = RoomCandidate(
      id: 'room-off',
      name: 'Suite',
      number: '3',
      isActive: false,
    );

    Future<Reservation> createForType(
      List<RoomCandidate> rooms, {
      String requestId = 'req-type',
      DateTime? checkIn,
      DateTime? checkOut,
    }) => service.createReservationForType(
      requestId: requestId,
      motelId: 'm1',
      motelName: 'Motel m1',
      rooms: rooms,
      checkIn: checkIn ?? at(11, 14),
      checkOut: checkOut ?? at(11, 18),
      stayMode: StayMode.dateTimeRange,
      guestCount: 2,
      services: const [],
      products: const [],
      roomTotal: 100000,
    );

    test('never assigns inactive rooms nor rooms with an overlap', () async {
      // room-a is busy at that time, room-off is inactive: only room-b fits.
      seed([reservation(checkIn: at(11, 14), checkOut: at(11, 18))]);

      final created = await createForType([roomA, roomB, roomOff]);

      expect(created.roomId, 'room-b');
      expect(created.status, ReservationStatus.pending);
    });

    test('assigns one of the free active rooms at random', () async {
      final assigned = <String>{};
      for (var i = 0; i < 40; i++) {
        seed(const []);
        service = BookingService(
          repository: repository,
          now: () => clock,
          random: Random(i),
        );
        assigned.add((await createForType([roomA, roomB])).roomId);
      }

      expect(assigned, {'room-a', 'room-b'});
    });

    test('rejects when no room of the type is active, whatever the dates '
        'or the stored reservations', () async {
      await expectLater(
        createForType([roomOff]),
        throwsA(
          isA<SlotUnavailableException>().having(
            (e) => e.message,
            'message',
            BookingService.noActiveUnitsMessage,
          ),
        ),
      );
      // Same rejection even with an invalid range.
      await expectLater(
        createForType([roomOff], checkIn: at(11, 18), checkOut: at(11, 14)),
        throwsA(
          isA<SlotUnavailableException>().having(
            (e) => e.message,
            'message',
            BookingService.noActiveUnitsMessage,
          ),
        ),
      );
      expect((await repository.getAll()), isEmpty);
    });

    test('rejects with the concurrency message when every active room '
        'overlaps, suggesting other dates or another type', () async {
      seed([
        reservation(id: 'r1', checkIn: at(11, 14), checkOut: at(11, 18)),
        reservation(
          id: 'r2',
          roomId: 'room-b',
          checkIn: at(11, 15),
          checkOut: at(11, 17),
        ),
      ]);

      await expectLater(
        createForType([roomA, roomB, roomOff]),
        throwsA(
          isA<SlotUnavailableException>().having(
            (e) => e.message,
            'message',
            allOf(contains('acaban de ser ocupados'), contains('tipo')),
          ),
        ),
      );
      expect((await repository.getAll()).length, 2);
    });

    test('a retry with the same requestId does not duplicate', () async {
      final first = await createForType([roomA, roomB]);
      final second = await createForType([roomA, roomB]);

      expect(second.id, first.id);
      expect((await repository.getAll()).length, 1);
    });

    test('validateTypeBooking mirrors the creation rules', () async {
      seed([reservation(checkIn: at(11, 14), checkOut: at(11, 18))]);
      final stored = await repository.getAll();

      expect(
        service.validateTypeBooking(stored, [roomOff], at(11, 14), at(11, 18)),
        BookingService.noActiveUnitsMessage,
      );
      expect(
        service.validateTypeBooking(stored, [roomA], at(11, 14), at(11, 18)),
        BookingService.slotTakenMessage,
      );
      expect(
        service.validateTypeBooking(
          stored,
          [roomA, roomB],
          at(11, 14),
          at(11, 18),
        ),
        isNull,
      );
      expect(
        service.validateTypeBooking(
          stored,
          [roomA, roomB],
          at(11, 18),
          at(11, 14),
        ),
        contains('posterior'),
      );
    });
  });
}
