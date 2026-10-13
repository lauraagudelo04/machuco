import 'package:machuco/models/booking/booking.dart';

/// Demo client that owns the client-side seed reservations. Shared with
/// `ClientBookingController` so "Mis reservas" shows exactly these.
const String demoClientUserId = 'user-demo-001';

/// Single seed source for the in-memory booking store. Every role (client,
/// owner, system admin) reads the very same reservations built here.
///
/// Ids are stable on purpose: widgets and tests refer to them.
/// Motel `'3'` (Motel Eclipse) is deliberately left without reservations to
/// cover the "motel without history" scenario of the admin dashboard.
List<Reservation> buildSeedReservations(DateTime now) {
  return [
    ..._clientSeeds(now),
    ..._ownerSeeds(now),
    // Past months of history so admin KPIs and charts have variety.
    ..._generateMotelHistory(
      motelId: '1',
      motelName: 'Motel Paraíso Élite',
      roomNumbers: const ['101', '102', '103'],
      baseNightly: 180000,
      baseMonthlyCount: 6,
      now: now,
    ),
    ..._generateMotelHistory(
      motelId: '2',
      motelName: 'Motel El Edén',
      roomNumbers: const ['201', '202'],
      baseNightly: 200000,
      baseMonthlyCount: 4,
      now: now,
    ),
  ];
}

List<Reservation> _clientSeeds(DateTime now) {
  DateTime at(Duration offset) => now.add(offset);

  return [
    Reservation(
      id: 'reservation-seed-completed',
      requestId: 'seed-completed',
      motelId: '1',
      motelName: 'Motel Paraíso Élite',
      roomId: 'room-101',
      roomName: 'Suite Aurora',
      roomNumber: '101',
      checkIn: at(const Duration(days: -6, hours: -3)),
      checkOut: at(const Duration(days: -6)),
      stayMode: StayMode.dateWithHourBlock,
      guestCount: 2,
      services: const [
        ReservationLineItem(
          id: 'service-jacuzzi',
          name: 'Jacuzzi privado',
          unitPrice: 25000,
        ),
      ],
      products: const [],
      roomTotal: 204000,
      total: 229000,
      status: ReservationStatus.completed,
      createdAt: at(const Duration(days: -6, hours: -4)),
      guestId: demoClientUserId,
      guestName: 'Usuario demo',
      categoryId: 3,
      paymentMethod: 'Tarjeta',
    ),
    Reservation(
      id: 'reservation-seed-cancelled',
      requestId: 'seed-cancelled',
      // Real id of "Motel El Edén" in MotelController, so the mocked review
      // with parentId "2" can be shown in the detail.
      motelId: '2',
      motelName: 'Motel El Edén',
      roomId: 'room-201',
      roomName: 'Suite Nova',
      roomNumber: '201',
      checkIn: at(const Duration(days: -3, hours: -2)),
      checkOut: at(const Duration(days: -3)),
      stayMode: StayMode.dateTimeRange,
      guestCount: 3,
      services: const [],
      products: const [
        ReservationLineItem(
          id: 'product-001',
          name: 'Gaseosa',
          unitPrice: 6000,
          quantity: 2,
        ),
      ],
      roomTotal: 104000,
      total: 116000,
      status: ReservationStatus.cancelled,
      createdAt: at(const Duration(days: -3, hours: -3)),
      guestId: demoClientUserId,
      guestName: 'Usuario demo',
      categoryId: 2,
    ),
    Reservation(
      id: 'reservation-seed-upcoming',
      requestId: 'seed-upcoming',
      motelId: '1',
      motelName: 'Motel Paraíso Élite',
      roomId: 'room-204',
      roomName: 'Loft Neon',
      roomNumber: '204',
      checkIn: at(const Duration(days: 2, hours: 20)),
      checkOut: at(const Duration(days: 3)),
      stayMode: StayMode.dateWithHourBlock,
      guestCount: 2,
      services: const [],
      products: const [],
      roomTotal: 156000,
      total: 156000,
      status: ReservationStatus.upcoming,
      createdAt: at(const Duration(days: -1)),
      guestId: demoClientUserId,
      guestName: 'Usuario demo',
      categoryId: 4,
      paymentMethod: 'Transferencia',
    ),
    Reservation(
      id: 'reservation-seed-active',
      requestId: 'seed-active',
      motelId: '1',
      motelName: 'Motel Paraíso Élite',
      roomId: 'room-101',
      roomName: 'Suite Aurora',
      roomNumber: '101',
      checkIn: at(const Duration(hours: -1)),
      checkOut: at(const Duration(hours: 2)),
      stayMode: StayMode.dateWithHourBlock,
      guestCount: 2,
      services: const [],
      products: const [],
      roomTotal: 204000,
      total: 204000,
      status: ReservationStatus.active,
      createdAt: at(const Duration(hours: -2)),
      guestId: demoClientUserId,
      guestName: 'Usuario demo',
      categoryId: 3,
      paymentMethod: 'Efectivo',
    ),
    Reservation(
      id: 'reservation-seed-pending',
      requestId: 'seed-pending',
      motelId: '2',
      motelName: 'Motel El Edén',
      roomId: 'room-402',
      roomName: 'Studio Loto',
      roomNumber: '402',
      checkIn: at(const Duration(hours: 3)),
      checkOut: at(const Duration(hours: 5)),
      stayMode: StayMode.dateWithHourBlock,
      guestCount: 4,
      services: const [],
      products: const [
        ReservationLineItem(id: 'product-004', name: 'Agua', unitPrice: 3000),
      ],
      roomTotal: 88000,
      total: 91000,
      status: ReservationStatus.pending,
      createdAt: now,
      guestId: demoClientUserId,
      guestName: 'Usuario demo',
      categoryId: 1,
    ),
  ];
}

List<Reservation> _ownerSeeds(DateTime now) {
  DateTime at(Duration offset) => now.add(offset);

  return [
    // Motel Paraíso Élite (id '1', owner-1020304050).
    Reservation(
      id: 'owner-reservation-001',
      requestId: 'owner-seed-001',
      categoryId: 1,
      motelId: '1',
      motelName: 'Motel Paraíso Élite',
      roomId: 'room-1-101',
      roomName: 'Suite Élite',
      roomNumber: '101',
      checkIn: at(const Duration(hours: -2)),
      checkOut: at(const Duration(hours: 1)),
      stayMode: StayMode.dateWithHourBlock,
      guestCount: 2,
      services: const [],
      products: const [],
      roomTotal: 180000,
      total: 180000,
      status: ReservationStatus.active,
      createdAt: at(const Duration(hours: -3)),
      guestId: 'client-001',
      guestName: 'Camila Restrepo',
      paymentMethod: 'Efectivo',
    ),
    Reservation(
      id: 'owner-reservation-002',
      requestId: 'owner-seed-002',
      categoryId: 2,
      motelId: '1',
      motelName: 'Motel Paraíso Élite',
      roomId: 'room-1-102',
      roomName: 'Suite Privilegio',
      roomNumber: '102',
      checkIn: at(const Duration(days: 1, hours: 4)),
      checkOut: at(const Duration(days: 1, hours: 8)),
      stayMode: StayMode.dateWithHourBlock,
      guestCount: 2,
      services: const [
        ReservationLineItem(
          id: 'service-desayuno',
          name: 'Desayuno a la habitación',
          unitPrice: 18000,
        ),
      ],
      products: const [],
      roomTotal: 150000,
      total: 168000,
      status: ReservationStatus.upcoming,
      createdAt: at(const Duration(hours: -6)),
      guestId: 'client-002',
      guestName: 'Julián Gómez',
      paymentMethod: 'Tarjeta',
    ),
    Reservation(
      id: 'owner-reservation-003',
      requestId: 'owner-seed-003',
      categoryId: 3,
      motelId: '1',
      motelName: 'Motel Paraíso Élite',
      roomId: 'room-1-101',
      roomName: 'Suite Élite',
      roomNumber: '101',
      checkIn: at(const Duration(days: 2, hours: 2)),
      checkOut: at(const Duration(days: 2, hours: 6)),
      stayMode: StayMode.dateWithHourBlock,
      guestCount: 3,
      services: const [],
      products: const [
        ReservationLineItem(
          id: 'product-gaseosa',
          name: 'Gaseosa',
          unitPrice: 6000,
          quantity: 2,
        ),
      ],
      roomTotal: 180000,
      total: 192000,
      status: ReservationStatus.pending,
      // Recent on purpose: pending reservations expire after 15 minutes.
      createdAt: at(const Duration(minutes: -1)),
      guestId: 'client-001',
      guestName: 'Camila Restrepo',
    ),
    // Motel El Edén (id '2', owner-1020304050).
    Reservation(
      id: 'owner-reservation-004',
      requestId: 'owner-seed-004',
      categoryId: 4,
      motelId: '2',
      motelName: 'Motel El Edén',
      roomId: 'room-2-201',
      roomName: 'Cabaña Bosque',
      roomNumber: '201',
      checkIn: at(const Duration(days: -4, hours: -3)),
      checkOut: at(const Duration(days: -4)),
      stayMode: StayMode.dateTimeRange,
      guestCount: 2,
      services: const [],
      products: const [],
      roomTotal: 210000,
      total: 210000,
      status: ReservationStatus.completed,
      createdAt: at(const Duration(days: -4, hours: -4)),
      guestId: 'client-003',
      guestName: 'Andrea Salazar',
      paymentMethod: 'Transferencia',
    ),
    Reservation(
      id: 'owner-reservation-005',
      requestId: 'owner-seed-005',
      categoryId: 5,
      motelId: '2',
      motelName: 'Motel El Edén',
      roomId: 'room-2-202',
      roomName: 'Cabaña Río',
      roomNumber: '202',
      checkIn: at(const Duration(days: -1, hours: -5)),
      checkOut: at(const Duration(days: -1, hours: -2)),
      stayMode: StayMode.dateWithHourBlock,
      guestCount: 4,
      services: const [],
      products: const [],
      roomTotal: 195000,
      total: 195000,
      status: ReservationStatus.cancelled,
      createdAt: at(const Duration(days: -1, hours: -6)),
      guestId: 'client-002',
      guestName: 'Julián Gómez',
      cancellationReason: 'El huésped solicitó reprogramar para otra fecha.',
    ),
    Reservation(
      id: 'owner-reservation-006',
      requestId: 'owner-seed-006',
      categoryId: 1,
      motelId: '2',
      motelName: 'Motel El Edén',
      roomId: 'room-2-201',
      roomName: 'Cabaña Bosque',
      roomNumber: '201',
      checkIn: at(const Duration(days: 3, hours: 6)),
      checkOut: at(const Duration(days: 3, hours: 10)),
      stayMode: StayMode.dateWithHourBlock,
      guestCount: 2,
      services: const [],
      products: const [],
      roomTotal: 210000,
      total: 210000,
      status: ReservationStatus.pending,
      createdAt: now,
      guestId: 'client-004',
      guestName: 'Santiago Marín',
    ),
  ];
}

/// Twelve months of finished reservations for a motel (completed or
/// cancelled). Slots that would end after [now] are skipped: reservations in
/// progress or in the future come from the explicit seeds above, so every
/// seeded status stays consistent with the clock.
List<Reservation> _generateMotelHistory({
  required String motelId,
  required String motelName,
  required List<String> roomNumbers,
  required int baseNightly,
  required int baseMonthlyCount,
  required DateTime now,
}) {
  final reservations = <Reservation>[];
  var sequence = 0;

  for (var monthsAgo = 11; monthsAgo >= 0; monthsAgo--) {
    final monthDate = DateTime(now.year, now.month - monthsAgo);
    final countThisMonth = baseMonthlyCount + (monthsAgo % 3 == 0 ? 2 : 0);

    for (var i = 0; i < countThisMonth; i++) {
      sequence++;
      final day = 1 + ((i * 5 + monthsAgo) % 26);
      final checkIn = DateTime(
        monthDate.year,
        monthDate.month,
        day,
        14 + (i % 4),
      );
      final checkOut = checkIn.add(Duration(hours: 3 + (i % 3)));
      if (checkOut.isAfter(now)) continue;

      final cancelled = (i + monthsAgo) % 5 == 0;
      final roomNumber = roomNumbers[i % roomNumbers.length];
      final total = baseNightly + (i % 3) * 15000;
      final id = '$motelId-admin-res-$sequence';

      reservations.add(
        Reservation(
          id: id,
          requestId: '$id-req',
          motelId: motelId,
          motelName: motelName,
          roomId: '$motelId-room-$roomNumber',
          roomName: 'Habitación $roomNumber',
          roomNumber: roomNumber,
          checkIn: checkIn,
          checkOut: checkOut,
          stayMode: StayMode.dateWithHourBlock,
          guestCount: 2,
          services: const [],
          products: const [],
          roomTotal: total,
          total: total,
          status: cancelled
              ? ReservationStatus.cancelled
              : ReservationStatus.completed,
          createdAt: checkIn.subtract(const Duration(hours: 2)),
          guestId: 'guest-$motelId-${i % 5}',
          guestName: _guestNameFor(i),
          categoryId: 1 + (i % 5),
          paymentMethod: cancelled ? null : _paymentMethodFor(sequence),
        ),
      );
    }
  }

  return reservations;
}

String _paymentMethodFor(int sequence) {
  const methods = ['Efectivo', 'Tarjeta', 'Transferencia'];
  return methods[sequence % methods.length];
}

String _guestNameFor(int index) {
  const names = [
    'Camila Restrepo',
    'Julián Gómez',
    'Andrea Salazar',
    'Santiago Marín',
    'Laura Gómez',
  ];
  return names[index % names.length];
}
