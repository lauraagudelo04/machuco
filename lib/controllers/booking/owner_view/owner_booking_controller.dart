import 'package:flutter/foundation.dart';

import 'package:machuco/controllers/motel/motel_controller.dart';
import 'package:machuco/models/booking/booking.dart';
import 'package:machuco/models/motel/motel_model.dart';
import 'package:machuco/utils/booking/reservation_cancellation_exception.dart';

export 'package:machuco/utils/booking/reservation_cancellation_exception.dart';

/// Controlador mock (patrón `ChangeNotifier`, sin backend) para la gestión
/// de reservas del Propietario: todas las reservas de los moteles que
/// administra, filtros combinados, métricas operativas y las acciones de
/// cobro en efectivo y cancelación.
///
/// El dataset (`_reservations`) es `static` y propio de este controller,
/// independiente del de `ClientBookingController`, siguiendo la nota del
/// feature de que "cada controller mantiene sus propios datos mockeados".
///
/// Los métodos públicos que representan consultas (`reservationsForOwner`,
/// `filteredReservations`, `reservationsForClient`, `getById`) son
/// `Future`-based a propósito, aunque hoy resuelven en memoria: así, en la
/// etapa 2 (backend real), su firma no debería tener que cambiar.
class OwnerBookingController extends ChangeNotifier {
  OwnerBookingController({
    this.ownerId = demoOwnerId,
    MotelController? motelController,
  }) : _motelController = motelController ?? MotelController();

  /// Propietario de demostración: coincide con el `ownerId` que ya trae
  /// mockeado `MotelController` (dueño de "Motel Paraíso Élite" y "Motel El
  /// Edén"), para que las reservas y los moteles calcen sin inventar una
  /// relación paralela.
  static const String demoOwnerId = 'owner-1020304050';

  final String ownerId;
  final MotelController _motelController;

  static final List<Reservation> _reservations = _seedReservations();

  bool _isLoading = false;
  String? _errorMessage;
  bool _isOffline = false;

  List<Motel> _ownedMotels = const [];
  List<Reservation> _ownedReservations = const [];

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isOffline => _isOffline;

  /// Moteles administrados por [ownerId], cacheados desde la última
  /// llamada exitosa a [loadReservations]. Útil para construir las
  /// opciones del filtro por motel sin repetir la consulta.
  List<Motel> get ownedMotels => List.unmodifiable(_ownedMotels);

  /// Reservas de los moteles administrados por [ownerId], cacheadas desde
  /// la última carga exitosa y ordenadas de más reciente a más antigua.
  List<Reservation> get ownedReservations {
    final list = List<Reservation>.from(_ownedReservations)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return List.unmodifiable(list);
  }

  /// Opciones de habitación (id → etiqueta) derivadas de las reservas
  /// cacheadas, para alimentar un filtro por habitación.
  List<ReservationRoomOption> get roomOptions {
    final byId = <String, ReservationRoomOption>{};
    for (final reservation in _ownedReservations) {
      byId[reservation.roomId] = ReservationRoomOption(
        roomId: reservation.roomId,
        label: '${reservation.roomNumber} · ${reservation.roomName}',
      );
    }
    final options = byId.values.toList()
      ..sort((a, b) => a.label.compareTo(b.label));
    return options;
  }

  /// Simula la carga inicial (o el refresco manual) de la vista de
  /// reservas del propietario. Igual patrón que `ClientBookingController`:
  /// expone `simulateError`/`simulateOffline` para poder demostrar de
  /// forma determinista los 6 estados exigidos a toda pantalla de datos.
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
      _errorMessage =
          'No pudimos cargar las reservas de tus moteles. Intenta de nuevo.';
      _isLoading = false;
      notifyListeners();
      return;
    }

    _ownedMotels = await _motelController.getMotelsByOwnerId(ownerId);
    final motelIds = _ownedMotels.map((motel) => motel.id).toSet();
    _ownedReservations = _reservations
        .where((reservation) => motelIds.contains(reservation.motelId))
        .toList();

    _isLoading = false;
    notifyListeners();
  }

  /// Todas las reservas de los moteles administrados por [ownerId], más
  /// recientes primero.
  Future<List<Reservation>> reservationsForOwner(String ownerId) async {
    final motels = await _motelController.getMotelsByOwnerId(ownerId);
    final motelIds = motels.map((motel) => motel.id).toSet();
    final list =
        _reservations
            .where((reservation) => motelIds.contains(reservation.motelId))
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return List.unmodifiable(list);
  }

  /// Aplica una combinación de filtros sobre el dataset del propietario
  /// actual (`this.ownerId`), ordenado por defecto de más reciente a más
  /// antigua.
  Future<List<Reservation>> filteredReservations({
    String? motelId,
    String? roomId,
    String? clientId,
    ReservationStatus? status,
  }) async {
    final owned = await reservationsForOwner(ownerId);
    final filtered = owned.where((reservation) {
      final matchesMotel =
          motelId == null || motelId.isEmpty || reservation.motelId == motelId;
      final matchesRoom =
          roomId == null || roomId.isEmpty || reservation.roomId == roomId;
      final matchesClient =
          clientId == null ||
          clientId.isEmpty ||
          reservation.guestId == clientId;
      final matchesStatus = status == null || reservation.status == status;
      return matchesMotel && matchesRoom && matchesClient && matchesStatus;
    }).toList();
    return List.unmodifiable(filtered);
  }

  /// Historial de reservas de un cliente específico, limitado a los
  /// moteles administrados por [ownerId] (el propietario recibido por
  /// parámetro, no necesariamente `this.ownerId`, para poder reutilizarse
  /// también desde un contexto que consulte otro propietario, p. ej. el
  /// futuro módulo de Clientes).
  Future<List<Reservation>> reservationsForClient(
    String ownerId,
    String clientId,
  ) async {
    final owned = await reservationsForOwner(ownerId);
    return List.unmodifiable(
      owned.where((reservation) => reservation.guestId == clientId),
    );
  }

  /// Métricas operativas (total, activas/próximas, pendientes de pago)
  /// para el resumen de la pantalla principal, opcionalmente acotadas a un
  /// solo motel. Es síncrono porque se apoya en `_ownedReservations`, ya
  /// cacheado por [loadReservations]; se recalcula en cada llamada (no
  /// cachea el resultado) para que refleje filtros aplicados en vivo.
  Map<String, int> operationalSummary({String? motelId}) {
    final scoped = motelId == null || motelId.isEmpty
        ? _ownedReservations
        : _ownedReservations.where(
            (reservation) => reservation.motelId == motelId,
          );
    final list = scoped.toList();
    final activeOrUpcoming = list
        .where(
          (reservation) =>
              reservation.status == ReservationStatus.active ||
              reservation.status == ReservationStatus.upcoming,
        )
        .length;
    final pendingPayment = list
        .where((reservation) => reservation.status == ReservationStatus.pending)
        .length;
    return {
      'total': list.length,
      'activeOrUpcoming': activeOrUpcoming,
      'pendingPayment': pendingPayment,
    };
  }

  Future<Reservation?> getById(String id) async {
    for (final reservation in _reservations) {
      if (reservation.id == id) return reservation;
    }
    return null;
  }

  /// Cancela una reserva y simula la notificación al cliente. Solo permitido
  /// si el estado actual es `pending` o `upcoming`; en cualquier otro caso
  /// (o si el motivo viene vacío, o si el id no existe) lanza
  /// [ReservationCancellationException] con un motivo específico, en vez de
  /// devolver silenciosamente `false`, para que la UI pueda mostrar un
  /// mensaje preciso.
  Future<void> cancelReservation(String id, String reason) async {
    if (reason.trim().isEmpty) {
      throw const ReservationCancellationException(
        ReservationCancellationError.reasonRequired,
      );
    }

    final index = _reservations.indexWhere(
      (reservation) => reservation.id == id,
    );
    if (index == -1) {
      throw const ReservationCancellationException(
        ReservationCancellationError.notFound,
      );
    }

    final reservation = _reservations[index];
    final cancellable =
        reservation.status == ReservationStatus.pending ||
        reservation.status == ReservationStatus.upcoming;
    if (!cancellable) {
      throw const ReservationCancellationException(
        ReservationCancellationError.invalidStatus,
      );
    }

    await Future<void>.delayed(const Duration(milliseconds: 400));

    _reservations[index] = reservation.copyWith(
      status: ReservationStatus.cancelled,
      cancellationReason: reason.trim(),
    );
    _syncOwnedReservation(_reservations[index]);

    // Notificación real fuera de alcance de esta rama: se simula solo de
    // forma visual/registrada, sin backend ni notificación real.
    debugPrint(
      'Notificación simulada: se avisó a "${reservation.guestName}" sobre '
      'la cancelación de la reserva $id.',
    );

    notifyListeners();
  }

  /// Registra el cobro en efectivo de una reserva como realizado. Si la
  /// reserva seguía `pending`, además la mueve a `active`/`upcoming` según
  /// la fecha de entrada (mismo gancho que `ClientBookingController
  /// .confirmPayment`, para no dejar el pago registrado con una reserva
  /// que sigue luciendo "pendiente de pago"). El acceso a la factura queda
  /// en `InvoiceAccessStatus.pending`: la generación real de facturas está
  /// fuera de alcance de este módulo.
  Future<void> registerCashPayment(String id) async {
    final index = _reservations.indexWhere(
      (reservation) => reservation.id == id,
    );
    if (index == -1) {
      throw const ReservationCancellationException(
        ReservationCancellationError.notFound,
      );
    }

    await Future<void>.delayed(const Duration(milliseconds: 400));

    final reservation = _reservations[index];
    final now = DateTime.now();
    final nextStatus = reservation.status == ReservationStatus.pending
        ? (now.isBefore(reservation.checkIn)
              ? ReservationStatus.upcoming
              : ReservationStatus.active)
        : reservation.status;

    _reservations[index] = reservation.copyWith(
      status: nextStatus,
      invoiceAccessStatus: InvoiceAccessStatus.pending,
    );
    _syncOwnedReservation(_reservations[index]);

    notifyListeners();
  }

  void _syncOwnedReservation(Reservation updated) {
    final index = _ownedReservations.indexWhere(
      (reservation) => reservation.id == updated.id,
    );
    if (index == -1) return;
    final next = List<Reservation>.from(_ownedReservations);
    next[index] = updated;
    _ownedReservations = next;
  }
}

/// Opción de habitación para un filtro (id + etiqueta legible).
class ReservationRoomOption {
  const ReservationRoomOption({required this.roomId, required this.label});

  final String roomId;
  final String label;
}

List<Reservation> _seedReservations() {
  final now = DateTime.now();
  DateTime at(Duration offset) => now.add(offset);

  return [
    // Motel Paraíso Élite (id '1', owner-1020304050).
    Reservation(
      id: 'owner-reservation-001',
      requestId: 'owner-seed-001',
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
    ),
    Reservation(
      id: 'owner-reservation-002',
      requestId: 'owner-seed-002',
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
    ),
    Reservation(
      id: 'owner-reservation-003',
      requestId: 'owner-seed-003',
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
      createdAt: at(const Duration(minutes: -40)),
      guestId: 'client-001',
      guestName: 'Camila Restrepo',
    ),
    // Motel El Edén (id '2', owner-1020304050).
    Reservation(
      id: 'owner-reservation-004',
      requestId: 'owner-seed-004',
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
    ),
    Reservation(
      id: 'owner-reservation-005',
      requestId: 'owner-seed-005',
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
