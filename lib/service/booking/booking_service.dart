import 'dart:math';

import 'package:machuco/models/booking/booking.dart';
import 'package:machuco/repositories/booking/booking_repository.dart';
import 'package:machuco/utils/booking/reservation_cancellation_exception.dart';
import 'package:machuco/utils/booking/reservation_transition_exception.dart';
import 'package:machuco/utils/date_formatter.dart';

/// Time range that is already taken by something that does not live in the
/// booking store, for example reservations mocked together with a room in
/// `RoomVisualData`. It is combined with the stored reservations when
/// computing availability.
class BlockedRange {
  const BlockedRange(this.start, this.end);
  final DateTime start;
  final DateTime end;
}

enum ReservationSortField { checkIn, createdAt, total }

/// Price of a stay, split in the parts shown in the booking summary.
class PriceBreakdown {
  const PriceBreakdown({
    required this.hours,
    required this.roomTotal,
    required this.servicesTotal,
    required this.productsTotal,
  });

  /// Billable hours (partial hours are rounded up). Zero without a range.
  final int hours;
  final int roomTotal;
  final int servicesTotal;
  final int productsTotal;

  int get total => roomTotal + servicesTotal + productsTotal;
}

/// Thrown by [BookingService.createReservation] when the requested slot
/// breaks a booking rule or is no longer free.
class SlotUnavailableException implements Exception {
  const SlotUnavailableException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// A specific room that can be assigned when booking a room type.
class RoomCandidate {
  const RoomCandidate({
    required this.id,
    required this.name,
    required this.number,
    this.isActive = true,
  });

  final String id;
  final String name;
  final String number;

  /// Whether the room can be offered for booking at all. Unrelated to the
  /// state of any reservation.
  final bool isActive;
}

/// KPI figures of one motel, derived from its reservations.
class MotelReservationKpis {
  const MotelReservationKpis({
    required this.totalReservations,
    required this.activeReservations,
    required this.cancelledReservations,
    required this.averagePerDay,
    required this.monthlyAverage,
    required this.occupancyRate,
    required this.totalRevenue,
  });

  final int totalReservations;

  /// Reservations that are active or upcoming.
  final int activeReservations;
  final int cancelledReservations;
  final double averagePerDay;
  final double monthlyAverage;
  final double occupancyRate;
  final int totalRevenue;
}

/// Number of reservations received during [month] (first day of the month).
class MonthlyReservationCount {
  const MonthlyReservationCount(this.month, this.count);
  final DateTime month;
  final int count;
}

class PaymentMethodTotal {
  const PaymentMethodTotal({
    required this.method,
    required this.total,
    required this.count,
  });

  final String method;
  final int total;
  final int count;
}

/// Paid reservations grouped by payment method, largest amount first.
class PaymentBreakdown {
  const PaymentBreakdown({
    required this.totalAmount,
    required this.totalCount,
    required this.byMethod,
  });

  final int totalAmount;
  final int totalCount;
  final List<PaymentMethodTotal> byMethod;
}

/// Business rules of the reservation module, shared by the client, owner and
/// system admin controllers: availability, pricing, status transitions,
/// pending payment expiration, and filter/sort/statistics helpers.
///
/// The service owns no state of its own: reservations live in the injected
/// [BookingRepository] and the current time comes from the injected clock, so
/// every rule can be tested deterministically.
class BookingService {
  BookingService({
    BookingRepository? repository,
    DateTime Function()? now,
    Random? random,
  }) : _repository = repository ?? BookingRepositoryProvider.instance,
       _now = now ?? DateTime.now,
       _random = random ?? Random();

  /// Message shown when no room of the requested type is active.
  static const String noActiveUnitsMessage =
      'No hay unidades disponibles de este tipo de habitación.';

  /// Message shown when the last free room was taken by someone else.
  static const String slotTakenMessage =
      'Esos horarios acaban de ser ocupados. Modifica las fechas y horas o '
      'elige otro tipo de habitación e inténtalo de nuevo.';

  /// Mandatory preparation time blocked after each reservation (if a
  /// reservation ends at 18:00, the next available start is 19:00).
  static const Duration preparationBuffer = Duration(hours: 1);

  /// Maximum time a reservation may stay `pending` without payment before it
  /// is cancelled automatically and its slot is released.
  static const Duration pendingPaymentTimeout = Duration(minutes: 15);

  /// Longest continuous stay allowed.
  static const Duration maxStayDuration = Duration(hours: 24);

  /// How far in the future a reservation can be made.
  static const Duration bookingHorizon = Duration(days: 365);

  /// Payment method recorded when the payment flow does not name one.
  static const String defaultPaymentMethod = 'Tarjeta';
  static const String cashPaymentMethod = 'Efectivo';

  static const String _autoCancelReason =
      'Cancelada automáticamente por falta de pago.';

  final BookingRepository _repository;
  final DateTime Function() _now;
  final Random _random;

  DateTime get now => _now();

  // ---------------------------------------------------------------------
  // Status transitions that only depend on the clock.
  // ---------------------------------------------------------------------

  /// Applies the transitions that happen just by time passing:
  /// - `pending` older than [pendingPaymentTimeout] becomes `cancelled`.
  /// - `upcoming` whose check-in has been reached becomes `active`.
  /// - `active` whose check-out time has been reached becomes `completed`.
  Reservation resolveReservation(Reservation reservation) {
    final current = now;
    var resolved = reservation;

    if (resolved.status == ReservationStatus.pending &&
        current.difference(resolved.createdAt) >= pendingPaymentTimeout) {
      return resolved.copyWith(
        status: ReservationStatus.cancelled,
        cancellationReason: _autoCancelReason,
      );
    }
    if (resolved.status == ReservationStatus.upcoming &&
        !current.isBefore(resolved.checkIn)) {
      resolved = resolved.copyWith(status: ReservationStatus.active);
    }
    if (resolved.status == ReservationStatus.active &&
        !current.isBefore(resolved.checkOut)) {
      resolved = resolved.copyWith(status: ReservationStatus.completed);
    }
    return resolved;
  }

  /// Pure version of [syncStatuses]: the same list with the clock based
  /// transitions applied but nothing persisted.
  List<Reservation> resolveStatuses(Iterable<Reservation> reservations) => [
    for (final reservation in reservations) resolveReservation(reservation),
  ];

  /// Remaining time before a `pending` reservation expires. `null` when the
  /// reservation is not pending (anymore).
  Duration? remainingPendingTime(Reservation reservation) {
    final resolved = resolveReservation(reservation);
    if (resolved.status != ReservationStatus.pending) return null;
    final remaining =
        pendingPaymentTimeout - now.difference(resolved.createdAt);
    return remaining.isNegative ? Duration.zero : remaining;
  }

  // ---------------------------------------------------------------------
  // Queries.
  // ---------------------------------------------------------------------

  /// Persists the clock based transitions and returns every reservation.
  Future<List<Reservation>> syncStatuses() async {
    final stored = await _repository.getAll();
    final result = <Reservation>[];
    for (final reservation in stored) {
      final resolved = resolveReservation(reservation);
      if (resolved.status != reservation.status) {
        await _repository.update(resolved);
      }
      result.add(resolved);
    }
    return result;
  }

  Future<List<Reservation>> getReservations() => syncStatuses();

  /// Reservation created by the request with this id, if any (used to make
  /// creation idempotent).
  Future<Reservation?> findByRequestId(String requestId) =>
      _repository.findByRequestId(requestId);

  Future<Reservation?> getReservation(String id) async {
    final stored = await _repository.getById(id);
    if (stored == null) return null;
    final resolved = resolveReservation(stored);
    if (resolved.status != stored.status) await _repository.update(resolved);
    return resolved;
  }

  // ---------------------------------------------------------------------
  // Availability.
  // ---------------------------------------------------------------------

  bool _blocksSlot(Reservation reservation) =>
      reservation.status == ReservationStatus.pending ||
      reservation.status == ReservationStatus.upcoming ||
      reservation.status == ReservationStatus.active;

  /// Two stays of the same room conflict when either starts before the other
  /// has ended plus the preparation buffer.
  bool _conflicts(
    DateTime start,
    DateTime end,
    DateTime otherStart,
    DateTime otherEnd,
  ) =>
      start.isBefore(otherEnd.add(preparationBuffer)) &&
      otherStart.isBefore(end.add(preparationBuffer));

  Iterable<Reservation> _blockingReservations(
    Iterable<Reservation> reservations,
    String roomId,
    DateTime start,
    DateTime end,
    String? excludingReservationId,
  ) {
    return resolveStatuses(reservations).where(
      (reservation) =>
          reservation.id != excludingReservationId &&
          reservation.roomId == roomId &&
          _blocksSlot(reservation) &&
          _conflicts(start, end, reservation.checkIn, reservation.checkOut),
    );
  }

  /// Whether `[start, end)` is free for [roomId], considering [reservations]
  /// (pending, upcoming and active ones), the preparation buffer around
  /// each of them, and any [externalBlocked] range.
  bool isSlotAvailable(
    Iterable<Reservation> reservations,
    String roomId,
    DateTime start,
    DateTime end, {
    List<BlockedRange> externalBlocked = const [],
    String? excludingReservationId,
    bool roomIsActive = true,
  }) {
    if (!roomIsActive) return false;
    if (!start.isBefore(end)) return false;

    final blockedByReservation = _blockingReservations(
      reservations,
      roomId,
      start,
      end,
      excludingReservationId,
    );
    if (blockedByReservation.isNotEmpty) return false;

    return !externalBlocked.any(
      (range) => _conflicts(start, end, range.start, range.end),
    );
  }

  /// Explains why a slot is blocked, to show it when the user picks a slot
  /// that is not available.
  String explainBlockedSlot(
    Iterable<Reservation> reservations,
    String roomId,
    DateTime start,
    DateTime end, {
    List<BlockedRange> externalBlocked = const [],
    String? excludingReservationId,
    bool roomIsActive = true,
  }) {
    if (!roomIsActive) {
      return 'Esta habitación no está disponible para reservar.';
    }

    final blocking = _blockingReservations(
      reservations,
      roomId,
      start,
      end,
      excludingReservationId,
    );
    if (blocking.isNotEmpty) {
      return _explain(blocking.first.checkIn, blocking.first.checkOut, end);
    }
    for (final range in externalBlocked) {
      if (_conflicts(start, end, range.start, range.end)) {
        return _explain(range.start, range.end, end);
      }
    }
    return 'Ese horario no está disponible. Elige otra franja.';
  }

  String _explain(DateTime blockedStart, DateTime blockedEnd, DateTime end) {
    if (!blockedStart.isBefore(end)) {
      return 'Ese horario deja menos de 1 hora de preparación antes de la '
          'reserva de las ${formatHourLabel(blockedStart)}.';
    }
    return 'Ese horario está ocupado hasta '
        '${formatHourLabel(blockedEnd.add(preparationBuffer))} '
        '(incluye 1 hora de preparación después de la reserva anterior).';
  }

  /// Checks the booking rules of a schedule that do not depend on other
  /// reservations. Returns a Spanish message for the first violated rule, or
  /// `null` when the schedule is acceptable.
  String? validateSchedule(
    DateTime checkIn,
    DateTime checkOut, {
    bool requireFutureCheckIn = true,
  }) {
    if (requireFutureCheckIn && checkIn.isBefore(now)) {
      return 'La hora de entrada debe ser posterior al momento actual.';
    }
    if (!checkOut.isAfter(checkIn)) {
      return 'La hora de salida debe ser posterior a la hora de entrada.';
    }
    if (checkOut.difference(checkIn) > maxStayDuration) {
      return 'La estancia no puede superar ${maxStayDuration.inHours} horas '
          'continuas.';
    }
    return null;
  }

  /// Full validation of a schedule for a room: booking rules plus
  /// availability. `null` means the schedule can be booked.
  String? validateBooking(
    Iterable<Reservation> reservations,
    String roomId,
    DateTime checkIn,
    DateTime checkOut, {
    List<BlockedRange> externalBlocked = const [],
    bool roomIsActive = true,
  }) {
    final ruleError = validateSchedule(checkIn, checkOut);
    if (ruleError != null) return ruleError;
    if (!isSlotAvailable(
      reservations,
      roomId,
      checkIn,
      checkOut,
      externalBlocked: externalBlocked,
      roomIsActive: roomIsActive,
    )) {
      return explainBlockedSlot(
        reservations,
        roomId,
        checkIn,
        checkOut,
        externalBlocked: externalBlocked,
        roomIsActive: roomIsActive,
      );
    }
    return null;
  }

  // ---------------------------------------------------------------------
  // Pricing.
  // ---------------------------------------------------------------------

  /// Price of a stay: the room is billed per started hour.
  PriceBreakdown calculatePrice({
    required int pricePerHour,
    DateTime? checkIn,
    DateTime? checkOut,
    List<ReservationLineItem> services = const [],
    List<ReservationLineItem> products = const [],
  }) {
    var hours = 0;
    if (checkIn != null && checkOut != null) {
      final minutes = checkOut.difference(checkIn).inMinutes;
      hours = minutes <= 0 ? 0 : (minutes / 60).ceil();
    }
    return PriceBreakdown(
      hours: hours,
      roomTotal: pricePerHour * hours,
      servicesTotal: services.fold(0, (sum, item) => sum + item.subtotal),
      productsTotal: products.fold(0, (sum, item) => sum + item.subtotal),
    );
  }

  // ---------------------------------------------------------------------
  // State changing operations.
  // ---------------------------------------------------------------------

  /// Creates a `pending` reservation. Idempotent by [requestId]: a retry of a
  /// request that was already stored returns the stored reservation.
  /// Revalidates the schedule and availability right before inserting and
  /// throws [SlotUnavailableException] when the slot cannot be booked.
  Future<Reservation> createReservation({
    required String requestId,
    required String motelId,
    required String motelName,
    required String roomId,
    required String roomName,
    required String roomNumber,
    required DateTime checkIn,
    required DateTime checkOut,
    required StayMode stayMode,
    required int guestCount,
    required List<ReservationLineItem> services,
    required List<ReservationLineItem> products,
    required int roomTotal,
    int? categoryId,
    String guestId = '',
    String guestName = '',
    List<BlockedRange> externalBlocked = const [],
    bool roomIsActive = true,
  }) async {
    final existing = await _repository.findByRequestId(requestId);
    if (existing != null) return existing;

    final ruleError = validateSchedule(
      checkIn,
      checkOut,
      requireFutureCheckIn: false,
    );
    if (ruleError != null) throw SlotUnavailableException(ruleError);

    final stored = await syncStatuses();
    if (!isSlotAvailable(
      stored,
      roomId,
      checkIn,
      checkOut,
      externalBlocked: externalBlocked,
      roomIsActive: roomIsActive,
    )) {
      throw const SlotUnavailableException(slotTakenMessage);
    }

    final price = calculatePrice(
      pricePerHour: 0,
      services: services,
      products: products,
    );
    final created = now;
    final reservation = Reservation(
      id: 'reservation-${created.microsecondsSinceEpoch}',
      requestId: requestId,
      motelId: motelId,
      motelName: motelName,
      roomId: roomId,
      roomName: roomName,
      roomNumber: roomNumber,
      checkIn: checkIn,
      checkOut: checkOut,
      stayMode: stayMode,
      guestCount: guestCount,
      services: services,
      products: products,
      roomTotal: roomTotal,
      total: roomTotal + price.servicesTotal + price.productsTotal,
      status: ReservationStatus.pending,
      createdAt: created,
      guestId: guestId,
      guestName: guestName,
      categoryId: categoryId,
    );
    await _repository.add(reservation);
    return reservation;
  }

  /// Active rooms of [rooms] that have no overlapping `pending`, `upcoming`
  /// or `active` reservation (buffer included) in `[start, end)`.
  List<RoomCandidate> freeRooms(
    Iterable<Reservation> reservations,
    Iterable<RoomCandidate> rooms,
    DateTime start,
    DateTime end,
  ) {
    final list = reservations.toList();
    return [
      for (final room in rooms)
        if (room.isActive && isSlotAvailable(list, room.id, start, end)) room,
    ];
  }

  /// Booking rules of a stay for a room type: schedule rules, then
  /// "no active unit" and "every active unit is taken". `null` means that at
  /// least one active room can be assigned.
  String? validateTypeBooking(
    Iterable<Reservation> reservations,
    Iterable<RoomCandidate> rooms,
    DateTime checkIn,
    DateTime checkOut,
  ) {
    if (!rooms.any((room) => room.isActive)) return noActiveUnitsMessage;
    final ruleError = validateSchedule(checkIn, checkOut);
    if (ruleError != null) return ruleError;
    if (freeRooms(reservations, rooms, checkIn, checkOut).isEmpty) {
      return slotTakenMessage;
    }
    return null;
  }

  /// Creates a `pending` reservation for a room type: discards inactive
  /// rooms, crosses the remaining ones against their reservations and
  /// assigns one free room at random. Idempotent by [requestId].
  ///
  /// Throws [SlotUnavailableException] when no room of the type is active
  /// ([noActiveUnitsMessage], whatever the dates) or when every active room
  /// overlaps the requested range ([slotTakenMessage]).
  Future<Reservation> createReservationForType({
    required String requestId,
    required String motelId,
    required String motelName,
    required List<RoomCandidate> rooms,
    required DateTime checkIn,
    required DateTime checkOut,
    required StayMode stayMode,
    required int guestCount,
    required List<ReservationLineItem> services,
    required List<ReservationLineItem> products,
    required int roomTotal,
    int? categoryId,
    String guestId = '',
    String guestName = '',
  }) async {
    final existing = await _repository.findByRequestId(requestId);
    if (existing != null) return existing;

    if (!rooms.any((room) => room.isActive)) {
      throw const SlotUnavailableException(noActiveUnitsMessage);
    }
    final ruleError = validateSchedule(
      checkIn,
      checkOut,
      requireFutureCheckIn: false,
    );
    if (ruleError != null) throw SlotUnavailableException(ruleError);

    final free = freeRooms(await syncStatuses(), rooms, checkIn, checkOut);
    if (free.isEmpty) throw const SlotUnavailableException(slotTakenMessage);
    final room = free[_random.nextInt(free.length)];

    return createReservation(
      requestId: requestId,
      motelId: motelId,
      motelName: motelName,
      roomId: room.id,
      roomName: room.name,
      roomNumber: room.number,
      checkIn: checkIn,
      checkOut: checkOut,
      stayMode: stayMode,
      guestCount: guestCount,
      services: services,
      products: products,
      roomTotal: roomTotal,
      categoryId: categoryId,
      guestId: guestId,
      guestName: guestName,
    );
  }

  Future<Reservation> _requireReservation(String id) async {
    final reservation = await getReservation(id);
    if (reservation == null) {
      throw const ReservationCancellationException(
        ReservationCancellationError.notFound,
      );
    }
    return reservation;
  }

  /// Confirms the payment of a `pending` reservation: it becomes `upcoming`
  /// or, if its check-in time has been reached, `active`.
  ///
  /// Throws [ReservationCancellationException] (`notFound`) for an unknown
  /// id and [ReservationTransitionException] if the reservation is not
  /// pending (including one that just expired).
  Future<Reservation> confirmPayment(
    String id, {
    String paymentMethod = defaultPaymentMethod,
  }) async {
    final reservation = await _requireReservation(id);
    if (reservation.status != ReservationStatus.pending) {
      throw ReservationTransitionException(reservation.status);
    }
    final paid = resolveReservation(
      reservation.copyWith(
        status: ReservationStatus.upcoming,
        paymentMethod: paymentMethod,
      ),
    );
    await _repository.update(paid);
    return paid;
  }

  /// Registers a cash payment. A `pending` reservation is paid like in
  /// [confirmPayment]; an `upcoming` or `active` one (already paid by other
  /// means) only gets its invoice access marked as pending. Invoice
  /// generation itself is out of scope of this module.
  ///
  /// Throws [ReservationCancellationException] (`notFound`) for an unknown
  /// id and [ReservationTransitionException] for a cancelled or completed
  /// reservation.
  Future<Reservation> registerCashPayment(String id) async {
    final reservation = await _requireReservation(id);
    if (reservation.status == ReservationStatus.cancelled ||
        reservation.status == ReservationStatus.completed) {
      throw ReservationTransitionException(reservation.status);
    }
    final paid = resolveReservation(
      reservation.copyWith(
        status: reservation.status == ReservationStatus.pending
            ? ReservationStatus.upcoming
            : reservation.status,
        paymentMethod: reservation.paymentMethod ?? cashPaymentMethod,
        invoiceAccessStatus: InvoiceAccessStatus.pending,
      ),
    );
    await _repository.update(paid);
    return paid;
  }

  /// Cancels a reservation. Only `pending` and `upcoming` reservations can be
  /// cancelled, and a non blank reason is mandatory. Throws
  /// [ReservationCancellationException] otherwise.
  Future<Reservation> cancelReservation(String id, String reason) async {
    if (reason.trim().isEmpty) {
      throw const ReservationCancellationException(
        ReservationCancellationError.reasonRequired,
      );
    }
    final reservation = await _requireReservation(id);
    final cancellable =
        reservation.status == ReservationStatus.pending ||
        reservation.status == ReservationStatus.upcoming;
    if (!cancellable) {
      throw const ReservationCancellationException(
        ReservationCancellationError.invalidStatus,
      );
    }
    final cancelled = reservation.copyWith(
      status: ReservationStatus.cancelled,
      cancellationReason: reason.trim(),
    );
    await _repository.update(cancelled);
    return cancelled;
  }

  // ---------------------------------------------------------------------
  // Filtering, sorting and statistics.
  // ---------------------------------------------------------------------

  /// Reservations matching every non empty criterion.
  List<Reservation> filterReservations(
    Iterable<Reservation> reservations, {
    Set<String>? motelIds,
    String? motelId,
    String? motelName,
    String? roomId,
    String? roomLabel,
    String? clientId,
    ReservationStatus? status,
    int? categoryId,
  }) {
    bool isSet(String? value) => value != null && value.isNotEmpty;

    return reservations.where((reservation) {
      return (motelIds == null || motelIds.contains(reservation.motelId)) &&
          (!isSet(motelId) || reservation.motelId == motelId) &&
          (!isSet(motelName) || reservation.motelName == motelName) &&
          (!isSet(roomId) || reservation.roomId == roomId) &&
          (!isSet(roomLabel) || roomLabelOf(reservation) == roomLabel) &&
          (!isSet(clientId) || reservation.guestId == clientId) &&
          (status == null || reservation.status == status) &&
          (categoryId == null || reservation.categoryId == categoryId);
    }).toList();
  }

  /// Human readable room label, for example `101 · Suite Aurora`.
  String roomLabelOf(Reservation reservation) =>
      '${reservation.roomNumber} · ${reservation.roomName}';

  List<Reservation> sortReservations(
    Iterable<Reservation> reservations, {
    ReservationSortField field = ReservationSortField.checkIn,
    bool descending = true,
  }) {
    int compare(Reservation a, Reservation b) => switch (field) {
      ReservationSortField.checkIn => a.checkIn.compareTo(b.checkIn),
      ReservationSortField.createdAt => a.createdAt.compareTo(b.createdAt),
      ReservationSortField.total => a.total.compareTo(b.total),
    };
    final list = reservations.toList();
    list.sort(descending ? (a, b) => compare(b, a) : compare);
    return list;
  }

  /// Total, active-or-upcoming and pending-payment counters.
  ({int total, int activeOrUpcoming, int pendingPayment}) operationalSummary(
    Iterable<Reservation> reservations,
  ) {
    final list = reservations.toList();
    return (
      total: list.length,
      activeOrUpcoming: list
          .where(
            (r) =>
                r.status == ReservationStatus.active ||
                r.status == ReservationStatus.upcoming,
          )
          .length,
      pendingPayment: list
          .where((r) => r.status == ReservationStatus.pending)
          .length,
    );
  }

  /// A reservation counts as paid when it is active, upcoming or completed;
  /// a `pending` one has not been paid and a `cancelled` one is assumed not
  /// to have been charged.
  bool isPaidStatus(ReservationStatus status) =>
      status == ReservationStatus.active ||
      status == ReservationStatus.upcoming ||
      status == ReservationStatus.completed;

  /// KPIs of one motel from its [reservations].
  ///
  /// The occupancy rate is an approximation (there is no real tracking of
  /// available room-nights in this stage): reservations whose check-in was in
  /// the last 30 days over the number of rooms, capped at 100%.
  MotelReservationKpis computeKpis(
    Iterable<Reservation> reservations, {
    required int roomCount,
  }) {
    final list = reservations.toList();
    final current = now;

    // The history covers the last 12 months (365 days).
    const historyDays = 365;
    final recent = list.where((reservation) {
      final days = current.difference(reservation.checkIn).inDays;
      return days >= 0 && days <= 30;
    }).length;

    return MotelReservationKpis(
      totalReservations: list.length,
      activeReservations: list
          .where(
            (r) =>
                r.status == ReservationStatus.active ||
                r.status == ReservationStatus.upcoming,
          )
          .length,
      cancelledReservations: list
          .where((r) => r.status == ReservationStatus.cancelled)
          .length,
      averagePerDay: list.length / historyDays,
      monthlyAverage: list.length / 12,
      occupancyRate: roomCount == 0
          ? 0.0
          : (recent / roomCount).clamp(0.0, 1.0),
      totalRevenue: list
          .where((r) => isPaidStatus(r.status))
          .fold(0, (sum, r) => sum + r.total),
    );
  }

  /// Reservations received per month during the last 12 months (by creation
  /// date), optionally restricted by [status] and [categoryId].
  List<MonthlyReservationCount> reservationsEvolution(
    Iterable<Reservation> reservations, {
    ReservationStatus? status,
    int? categoryId,
  }) {
    final current = now;
    final months = [
      for (var i = 11; i >= 0; i--) DateTime(current.year, current.month - i),
    ];
    final counts = {for (final month in months) _monthKey(month): 0};

    for (final reservation in reservations) {
      if (status != null && reservation.status != status) continue;
      if (categoryId != null && reservation.categoryId != categoryId) continue;
      final key = _monthKey(reservation.createdAt);
      if (counts.containsKey(key)) counts[key] = counts[key]! + 1;
    }

    return [
      for (final month in months)
        MonthlyReservationCount(month, counts[_monthKey(month)]!),
    ];
  }

  String _monthKey(DateTime date) => '${date.year}-${date.month}';

  /// Paid reservations grouped by payment method, largest amount first.
  PaymentBreakdown paymentBreakdown(Iterable<Reservation> reservations) {
    final totals = <String, int>{};
    final counts = <String, int>{};
    var totalAmount = 0;
    var totalCount = 0;

    for (final reservation in reservations) {
      if (!isPaidStatus(reservation.status)) continue;
      final method = reservation.paymentMethod ?? 'Sin registrar';
      totals[method] = (totals[method] ?? 0) + reservation.total;
      counts[method] = (counts[method] ?? 0) + 1;
      totalAmount += reservation.total;
      totalCount++;
    }

    final byMethod = [
      for (final entry in totals.entries)
        PaymentMethodTotal(
          method: entry.key,
          total: entry.value,
          count: counts[entry.key] ?? 0,
        ),
    ]..sort((a, b) => b.total.compareTo(a.total));

    return PaymentBreakdown(
      totalAmount: totalAmount,
      totalCount: totalCount,
      byMethod: byMethod,
    );
  }
}
