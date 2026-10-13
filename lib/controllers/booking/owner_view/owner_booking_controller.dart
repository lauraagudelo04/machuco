import 'package:flutter/foundation.dart';

import 'package:machuco/controllers/motel/motel_controller.dart';
import 'package:machuco/models/booking/booking.dart';
import 'package:machuco/models/booking/reservation_category.dart';
import 'package:machuco/repositories/booking/reservation_category_repository.dart';
import 'package:machuco/models/motel/motel_model.dart';
import 'package:machuco/service/booking/booking_service.dart';
import 'package:machuco/utils/booking/reservation_cancellation_exception.dart';
import 'package:machuco/utils/booking/reservation_transition_exception.dart';

export 'package:machuco/utils/booking/reservation_cancellation_exception.dart';
export 'package:machuco/utils/booking/reservation_transition_exception.dart';

/// Controlador mock (patrón `ChangeNotifier`, sin backend) para la gestión
/// de reservas del Propietario: todas las reservas de los moteles que
/// administra, filtros combinados, métricas operativas y las acciones de
/// cobro en efectivo y cancelación.
///
/// Solo guarda estado de pantalla (carga, error, caché de las reservas del
/// propietario) y delega las reglas de negocio en `BookingService`. Las
/// reservas viven en el `BookingRepository` compartido, así que el
/// propietario ve de inmediato lo que crea el cliente.
///
/// Los métodos públicos que representan consultas (`reservationsForOwner`,
/// `filteredReservations`, `reservationsForClient`, `getById`) son
/// `Future`-based a propósito, aunque hoy resuelven en memoria: así, en la
/// etapa 2 (backend real), su firma no debería tener que cambiar.
class OwnerBookingController extends ChangeNotifier {
  OwnerBookingController({
    this.ownerId = demoOwnerId,
    MotelController? motelController,
    ReservationCategoryRepository? categoryRepository,
    BookingService? bookingService,
  }) : _motelController = motelController ?? MotelController(),
       _categoryRepository =
           categoryRepository ?? ReservationCategoryRepositoryProvider.instance,
       _service = bookingService ?? BookingService();

  /// Propietario de demostración: coincide con el `ownerId` que ya trae
  /// mockeado `MotelController` (dueño de "Motel Paraíso Élite" y "Motel El
  /// Edén"), para que las reservas y los moteles calcen sin inventar una
  /// relación paralela.
  static const String demoOwnerId = 'owner-1020304050';

  final String ownerId;
  final MotelController _motelController;
  final ReservationCategoryRepository _categoryRepository;
  final BookingService _service;

  List<ReservationCategory> _categories = const [];

  /// Category catalog cached by [loadReservations], used to build the
  /// category filter. Empty if the catalog could not be loaded.
  List<ReservationCategory> get categories => List.unmodifiable(_categories);

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
    return List.unmodifiable(
      _service.sortReservations(
        _ownedReservations,
        field: ReservationSortField.createdAt,
      ),
    );
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

    try {
      _categories = await _categoryRepository.getCategories();
    } catch (_) {
      // The category filter is optional: reservations still load without it.
      _categories = const [];
    }

    _ownedMotels = await _motelController.getMotelsByOwnerId(ownerId);
    await _reloadOwnedReservations();

    _isLoading = false;
    notifyListeners();
  }

  /// Todas las reservas de los moteles administrados por [ownerId], más
  /// recientes primero.
  Future<List<Reservation>> reservationsForOwner(String ownerId) async {
    final motels = await _motelController.getMotelsByOwnerId(ownerId);
    final motelIds = motels.map((motel) => motel.id).toSet();
    final owned = _service.filterReservations(
      await _service.getReservations(),
      motelIds: motelIds,
    );
    return List.unmodifiable(
      _service.sortReservations(owned, field: ReservationSortField.createdAt),
    );
  }

  /// Aplica una combinación de filtros sobre el dataset del propietario
  /// actual (`this.ownerId`), ordenado por defecto de más reciente a más
  /// antigua.
  Future<List<Reservation>> filteredReservations({
    String? motelId,
    String? roomId,
    String? clientId,
    ReservationStatus? status,
    int? categoryId,
  }) async {
    final owned = await reservationsForOwner(ownerId);
    return List.unmodifiable(
      _service.filterReservations(
        owned,
        motelId: motelId,
        roomId: roomId,
        clientId: clientId,
        status: status,
        categoryId: categoryId,
      ),
    );
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
    final summary = _service.operationalSummary(
      _service.filterReservations(_ownedReservations, motelId: motelId),
    );
    return {
      'total': summary.total,
      'activeOrUpcoming': summary.activeOrUpcoming,
      'pendingPayment': summary.pendingPayment,
    };
  }

  Future<Reservation?> getById(String id) => _service.getReservation(id);

  /// Cancela una reserva y simula la notificación al cliente. Solo permitido
  /// si el estado actual es `pending` o `upcoming`; en cualquier otro caso
  /// (o si el motivo viene vacío, o si el id no existe) lanza
  /// [ReservationCancellationException] con un motivo específico, en vez de
  /// devolver silenciosamente `false`, para que la UI pueda mostrar un
  /// mensaje preciso.
  Future<void> cancelReservation(String id, String reason) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    final cancelled = await _service.cancelReservation(id, reason);
    await _reloadOwnedReservations();

    // Notificación real fuera de alcance de esta rama: se simula solo de
    // forma visual/registrada, sin backend ni notificación real.
    debugPrint(
      'Notificación simulada: se avisó a "${cancelled.guestName}" sobre '
      'la cancelación de la reserva $id.',
    );

    notifyListeners();
  }

  /// Registra el cobro en efectivo de una reserva como realizado. Si la
  /// reserva seguía `pending`, además la mueve a `active`/`upcoming` según
  /// la fecha de entrada. El acceso a la factura queda en
  /// `InvoiceAccessStatus.pending`: la generación real de facturas está
  /// fuera de alcance de este módulo.
  ///
  /// Lanza [ReservationCancellationException] (`notFound`) si el id no
  /// existe y [ReservationTransitionException] si la reserva está
  /// cancelada o completada.
  Future<void> registerCashPayment(String id) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    await _service.registerCashPayment(id);
    await _reloadOwnedReservations();
    notifyListeners();
  }

  Future<void> _reloadOwnedReservations() async {
    final motelIds = _ownedMotels.map((motel) => motel.id).toSet();
    _ownedReservations = _service.filterReservations(
      await _service.getReservations(),
      motelIds: motelIds,
    );
  }
}

/// Opción de habitación para un filtro (id + etiqueta legible).
class ReservationRoomOption {
  const ReservationRoomOption({required this.roomId, required this.label});

  final String roomId;
  final String label;
}
