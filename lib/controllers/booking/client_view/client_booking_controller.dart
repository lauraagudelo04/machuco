import 'package:flutter/foundation.dart';

import 'package:machuco/models/booking/booking.dart';
import 'package:machuco/utils/date_formatter.dart';

/// Franja bloqueada que no vive en el mock de este controlador, por ejemplo
/// reservas de otras funcionalidades ya mockeadas en `RoomVisualData`
/// (`lib/views/room/room_view_models.dart`). Se combina con el estado
/// propio del controlador para calcular disponibilidad real de una franja.
class BlockedRange {
  const BlockedRange(this.start, this.end);
  final DateTime start;
  final DateTime end;
}

enum CreateReservationOutcome { success, conflict, networkError }

class CreateReservationResult {
  const CreateReservationResult._(
    this.outcome, {
    this.reservation,
    this.message,
  });

  const CreateReservationResult.success(Reservation reservation)
    : this._(CreateReservationOutcome.success, reservation: reservation);

  const CreateReservationResult.conflict(String message)
    : this._(CreateReservationOutcome.conflict, message: message);

  const CreateReservationResult.networkError(String message)
    : this._(CreateReservationOutcome.networkError, message: message);

  final CreateReservationOutcome outcome;
  final Reservation? reservation;
  final String? message;

  bool get isSuccess => outcome == CreateReservationOutcome.success;
}

enum ReservationSortField { checkIn, createdAt, total }

/// Controlador mock (patrón `ChangeNotifier`, sin backend) para la reserva
/// de habitaciones y la gestión de "mis reservas" del cliente.
///
/// El estado (`_reservations`) es `static` a propósito: cada pantalla crea
/// su propia instancia de este controlador (mismo patrón que
/// `ProductController`/`AdditionalServiceClientController`), pero todas
/// deben leer y escribir la misma "base de datos" en memoria para que una
/// reserva creada en `CreateBookingPage` aparezca de inmediato en
/// `ClientReservationsPage` sin depender de un backend ni de un paquete de
/// gestión de estado adicional.
class ClientBookingController extends ChangeNotifier {
  ClientBookingController({this.userId = demoUserId});

  static const String demoUserId = 'user-demo-001';

  /// Tiempo de preparación obligatorio que se bloquea automáticamente
  /// después de cada reserva (si una reserva termina a las 18:00, el
  /// próximo horario disponible es 19:00).
  static const Duration preparationBuffer = Duration(hours: 1);

  /// Tiempo máximo que una reserva puede permanecer en `pending` sin pago
  /// antes de cancelarse automáticamente y liberar la franja.
  static const Duration pendingPaymentTimeout = Duration(minutes: 15);

  final String userId;

  static final List<Reservation> _reservations = _seedReservations();

  /// Solicitudes de creación que ya "fallaron por red" una vez, para que el
  /// reintento con el mismo `requestId` tenga éxito de forma determinista
  /// (permite demostrar el escenario de interrupción de red sin
  /// aleatoriedad y sin duplicar la reserva).
  static final Set<String> _requestIdsWithSimulatedFailure = {};

  bool _isLoading = false;
  String? _errorMessage;
  bool _isOffline = false;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isOffline => _isOffline;

  /// Todas las reservas en memoria, más recientes primero, aplicando antes
  /// la expiración automática de reservas `pending` abandonadas.
  List<Reservation> get reservations {
    _expirePendingReservations();
    final list = List<Reservation>.from(_reservations);
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return List.unmodifiable(list);
  }

  List<String> get motelNames {
    final names = {
      for (final reservation in reservations) reservation.motelName,
    };
    return names.toList()..sort();
  }

  List<String> get roomLabelsFor => reservations
      .map(
        (reservation) => '${reservation.roomNumber} · ${reservation.roomName}',
      )
      .toSet()
      .toList();

  /// Simula la carga inicial (o el refresco manual) de "Mis reservas".
  /// Expone los ganchos `simulateError`/`simulateOffline` para poder
  /// demostrar de forma determinista los estados de error recuperable y
  /// sin conexión exigidos para toda pantalla de datos.
  Future<void> loadReservations({
    bool simulateError = false,
    bool simulateOffline = false,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    _isOffline = false;
    notifyListeners();

    await Future<void>.delayed(const Duration(milliseconds: 500));

    if (simulateOffline) {
      _isOffline = true;
      _isLoading = false;
      notifyListeners();
      return;
    }
    if (simulateError) {
      _errorMessage = 'No pudimos cargar tus reservas. Intenta de nuevo.';
      _isLoading = false;
      notifyListeners();
      return;
    }

    _expirePendingReservations();
    _isLoading = false;
    notifyListeners();
  }

  List<Reservation> filteredReservations({
    String? motelName,
    String? roomLabel,
    ReservationSortField sortField = ReservationSortField.checkIn,
    bool descending = true,
  }) {
    final list = reservations.where((reservation) {
      final matchesMotel =
          motelName == null ||
          motelName.isEmpty ||
          reservation.motelName == motelName;
      final matchesRoom =
          roomLabel == null ||
          roomLabel.isEmpty ||
          '${reservation.roomNumber} · ${reservation.roomName}' == roomLabel;
      return matchesMotel && matchesRoom;
    }).toList();

    int compare(Reservation a, Reservation b) => switch (sortField) {
      ReservationSortField.checkIn => a.checkIn.compareTo(b.checkIn),
      ReservationSortField.createdAt => a.createdAt.compareTo(b.createdAt),
      ReservationSortField.total => a.total.compareTo(b.total),
    };
    list.sort(descending ? (a, b) => compare(b, a) : compare);
    return list;
  }

  Reservation? getById(String id) {
    _expirePendingReservations();
    for (final reservation in _reservations) {
      if (reservation.id == id) return reservation;
    }
    return null;
  }

  /// Indica si la franja `[start, end)` está disponible para `roomId`,
  /// teniendo en cuenta tanto las reservas de este controlador como el
  /// bloqueo de 1 hora de preparación posterior a cada una, y cualquier
  /// franja externa ya ocupada (por ejemplo, reservas mockeadas junto con
  /// la habitación en `RoomVisualData`).
  bool isSlotAvailable(
    String roomId,
    DateTime start,
    DateTime end, {
    List<BlockedRange> externalBlocked = const [],
    String? excludingReservationId,
  }) {
    if (!start.isBefore(end)) return false;
    _expirePendingReservations();

    final overlapsMock = _reservations.any((reservation) {
      if (reservation.id == excludingReservationId) return false;
      if (reservation.roomId != roomId) return false;
      if (reservation.status == ReservationStatus.cancelled) return false;
      final blockedEnd = reservation.checkOut.add(preparationBuffer);
      return start.isBefore(blockedEnd) && end.isAfter(reservation.checkIn);
    });
    if (overlapsMock) return false;

    final overlapsExternal = externalBlocked.any((range) {
      final blockedEnd = range.end.add(preparationBuffer);
      return start.isBefore(blockedEnd) && end.isAfter(range.start);
    });
    return !overlapsExternal;
  }

  /// Un día se resalta como "con disponibilidad" si existe al menos una
  /// hora libre dentro de él.
  bool isDayAvailable(
    String roomId,
    DateTime day, {
    List<BlockedRange> externalBlocked = const [],
  }) {
    final dayStart = DateTime(day.year, day.month, day.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    for (
      var hour = dayStart;
      hour.isBefore(dayEnd);
      hour = hour.add(const Duration(hours: 1))
    ) {
      if (isSlotAvailable(
        roomId,
        hour,
        hour.add(const Duration(hours: 1)),
        externalBlocked: externalBlocked,
      )) {
        return true;
      }
    }
    return false;
  }

  /// Explica por qué una franja específica está bloqueada, para mostrarlo
  /// cuando el usuario fuerza un horario no disponible.
  String explainBlockedSlot(
    String roomId,
    DateTime start,
    DateTime end, {
    List<BlockedRange> externalBlocked = const [],
  }) {
    final blockingReservation = _reservations
        .where(
          (reservation) =>
              reservation.roomId == roomId &&
              reservation.status != ReservationStatus.cancelled &&
              start.isBefore(reservation.checkOut.add(preparationBuffer)) &&
              end.isAfter(reservation.checkIn),
        )
        .toList();
    if (blockingReservation.isNotEmpty) {
      final blocking = blockingReservation.first;
      return 'Ese horario está ocupado hasta '
          '${formatHourLabel(blocking.checkOut.add(preparationBuffer))} '
          '(incluye 1 hora de preparación después de la reserva anterior).';
    }
    final blockingExternal = externalBlocked.where(
      (range) =>
          start.isBefore(range.end.add(preparationBuffer)) &&
          end.isAfter(range.start),
    );
    if (blockingExternal.isNotEmpty) {
      final blocking = blockingExternal.first;
      return 'Ese horario está ocupado hasta '
          '${formatHourLabel(blocking.end.add(preparationBuffer))} '
          '(incluye 1 hora de preparación después de la reserva anterior).';
    }
    return 'Ese horario no está disponible. Elige otra franja.';
  }

  /// Crea una reserva en memoria con estado `pending`. Ver escenarios de
  /// concurrencia e interrupción de red: revalida disponibilidad justo
  /// antes de insertar y es idempotente por `requestId`.
  Future<CreateReservationResult> createReservation({
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
    List<BlockedRange> externalBlocked = const [],
    bool simulateNetworkFailure = false,
    bool simulateConcurrentConflict = false,
  }) async {
    _errorMessage = null;
    notifyListeners();
    await Future<void>.delayed(const Duration(milliseconds: 500));

    // Idempotencia: si esta misma solicitud ya se creó (por ejemplo, un
    // reintento tras un error de red que en realidad sí llegó a "guardar"
    // la reserva), se devuelve la reserva existente en vez de duplicarla.
    for (final reservation in _reservations) {
      if (reservation.requestId == requestId) {
        return CreateReservationResult.success(reservation);
      }
    }

    if (simulateNetworkFailure &&
        _requestIdsWithSimulatedFailure.add(requestId)) {
      const message =
          'No fue posible conectar con el servidor. Puedes reintentar sin riesgo de duplicar tu reserva.';
      _errorMessage = message;
      notifyListeners();
      return const CreateReservationResult.networkError(message);
    }

    final stillAvailable = isSlotAvailable(
      roomId,
      checkIn,
      checkOut,
      externalBlocked: externalBlocked,
    );
    if (simulateConcurrentConflict || !stillAvailable) {
      const message =
          'Ese horario acaba de ocuparse. Actualiza el calendario e intenta con otra franja.';
      _errorMessage = message;
      notifyListeners();
      return const CreateReservationResult.conflict(message);
    }

    final servicesTotal = services.fold<int>(
      0,
      (sum, item) => sum + item.subtotal,
    );
    final productsTotal = products.fold<int>(
      0,
      (sum, item) => sum + item.subtotal,
    );

    final reservation = Reservation(
      id: 'reservation-${DateTime.now().microsecondsSinceEpoch}',
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
      total: roomTotal + servicesTotal + productsTotal,
      status: ReservationStatus.pending,
      createdAt: DateTime.now(),
    );

    _reservations.add(reservation);
    notifyListeners();
    return CreateReservationResult.success(reservation);
  }

  /// Gancho listo para cuando la feature real de pago esté disponible: ante
  /// una transacción exitosa, mueve la reserva a `active` o `upcoming`
  /// según la fecha de entrada y deja la habitación reservada de forma
  /// definitiva. No hay ninguna pantalla en este alcance que dispare este
  /// método (el procesamiento real de pagos está fuera de alcance).
  Future<bool> confirmPayment(String reservationId) async {
    _expirePendingReservations();
    final index = _reservations.indexWhere((r) => r.id == reservationId);
    if (index == -1) return false;
    final reservation = _reservations[index];
    if (reservation.status != ReservationStatus.pending) return false;

    await Future<void>.delayed(const Duration(milliseconds: 400));
    final now = DateTime.now();
    final nextStatus = now.isBefore(reservation.checkIn)
        ? ReservationStatus.upcoming
        : ReservationStatus.active;
    _reservations[index] = reservation.copyWith(status: nextStatus);
    notifyListeners();
    return true;
  }

  /// Minutos restantes antes de que una reserva `pending` se cancele
  /// automáticamente por abandono de pago. `null` si ya no aplica.
  Duration? remainingPendingTime(String reservationId) {
    final reservation = getById(reservationId);
    if (reservation == null ||
        reservation.status != ReservationStatus.pending) {
      return null;
    }
    final elapsed = DateTime.now().difference(reservation.createdAt);
    final remaining = pendingPaymentTimeout - elapsed;
    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// Revisa y expira (mueve a `cancelled`) cualquier reserva `pending` que
  /// superó el tiempo máximo de espera de pago. Se invoca de forma perezosa
  /// en cada lectura, y puede llamarse manualmente desde una pantalla con
  /// una cuenta regresiva visible (por ejemplo, el resumen previo al pago).
  void checkExpirations() => _expirePendingReservations();

  void _expirePendingReservations() {
    final now = DateTime.now();
    var changed = false;
    for (var i = 0; i < _reservations.length; i++) {
      final reservation = _reservations[i];
      if (reservation.status == ReservationStatus.pending &&
          now.difference(reservation.createdAt) >= pendingPaymentTimeout) {
        _reservations[i] = reservation.copyWith(
          status: ReservationStatus.cancelled,
        );
        changed = true;
      }
    }
    if (changed) notifyListeners();
  }
}

List<Reservation> _seedReservations() {
  final now = DateTime.now();
  DateTime at(Duration offset) => now.add(offset);

  return [
    Reservation(
      id: 'reservation-seed-completed',
      requestId: 'seed-completed',
      motelId: 'motel-eclipse',
      motelName: 'Motel Eclipse',
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
    ),
    Reservation(
      id: 'reservation-seed-cancelled',
      requestId: 'seed-cancelled',
      motelId: 'motel-nova',
      motelName: 'Motel Nova',
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
    ),
    Reservation(
      id: 'reservation-seed-upcoming',
      requestId: 'seed-upcoming',
      motelId: 'motel-eclipse',
      motelName: 'Motel Eclipse',
      roomId: 'room-305',
      roomName: 'Cabina Prisma',
      roomNumber: '305',
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
    ),
    Reservation(
      id: 'reservation-seed-active',
      requestId: 'seed-active',
      motelId: 'motel-eclipse',
      motelName: 'Motel Eclipse',
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
    ),
    Reservation(
      id: 'reservation-seed-pending',
      requestId: 'seed-pending',
      motelId: 'motel-eclipse',
      motelName: 'Motel Eclipse',
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
    ),
  ];
}
