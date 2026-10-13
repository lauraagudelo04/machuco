import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:machuco/controllers/motel/motel_controller.dart';
import 'package:machuco/models/booking/booking.dart';
import 'package:machuco/models/booking/reservation_category.dart';
import 'package:machuco/models/motel/motel_model.dart';
import 'package:machuco/repositories/booking/booking_seed_data.dart';
import 'package:machuco/repositories/booking/reservation_category_repository.dart';
import 'package:machuco/service/booking/booking_service.dart';
import 'package:machuco/utils/booking/reservation_cancellation_exception.dart';
import 'package:machuco/utils/booking/reservation_transition_exception.dart';

export 'package:machuco/service/booking/booking_service.dart'
    show BlockedRange, PriceBreakdown, ReservationSortField;
export 'package:machuco/utils/booking/reservation_cancellation_exception.dart';
export 'package:machuco/utils/booking/reservation_transition_exception.dart';

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

/// UI state controller (`ChangeNotifier`) for booking a room and for the
/// client's "mis reservas".
///
/// It only holds screen state (loading/error flags, category selection, a
/// snapshot of the reservations) and delegates every business rule to
/// [BookingService]. Reservations live in the shared `BookingRepository`, so
/// what the client creates is immediately visible to owner and admin too.
///
/// The snapshot is filled by [refresh] / [loadReservations]; the synchronous
/// getters ([reservations], [getById], [isSlotAvailable], ...) read from it.
/// The pending payment expiration is evaluated on every read of the snapshot
/// and, for screens with a visible countdown, by [startExpirationWatch].
class ClientBookingController extends ChangeNotifier {
  ClientBookingController({
    this.userId = demoUserId,
    MotelController? motelController,
    ReservationCategoryRepository? categoryRepository,
    BookingService? bookingService,
  }) : _motelController = motelController ?? MotelController(),
       _categoryRepository =
           categoryRepository ?? ReservationCategoryRepositoryProvider.instance,
       _service = bookingService ?? BookingService();

  static const String demoUserId = demoClientUserId;

  /// Mandatory preparation time blocked after every reservation.
  static const Duration preparationBuffer = BookingService.preparationBuffer;

  /// Maximum time a reservation can stay `pending` without payment.
  static const Duration pendingPaymentTimeout =
      BookingService.pendingPaymentTimeout;

  /// How far in the future a reservation can be made.
  static const Duration bookingHorizon = BookingService.bookingHorizon;

  final String userId;

  final MotelController _motelController;
  final ReservationCategoryRepository _categoryRepository;
  final BookingService _service;

  /// Requests that already "failed by network" once, so the retry with the
  /// same `requestId` succeeds deterministically (demonstrates the network
  /// interruption scenario without randomness and without duplicating the
  /// reservation).
  static final Set<String> _requestIdsWithSimulatedFailure = {};

  List<ReservationCategory> _categories = const [];
  bool _isLoadingCategories = false;
  String? _categoriesError;
  int? _selectedCategoryId;

  List<Reservation> _snapshot = const [];
  bool _isLoading = false;
  String? _errorMessage;
  bool _isOffline = false;
  Timer? _expirationTimer;
  bool _isDisposed = false;

  List<ReservationCategory> get categories => List.unmodifiable(_categories);
  bool get isLoadingCategories => _isLoadingCategories;
  String? get categoriesError => _categoriesError;
  int? get selectedCategoryId => _selectedCategoryId;

  /// A category must be selected before a reservation can be created.
  bool get hasCategorySelected => _selectedCategoryId != null;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isOffline => _isOffline;

  @override
  void notifyListeners() {
    if (_isDisposed) return;
    super.notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _expirationTimer?.cancel();
    super.dispose();
  }

  /// Loads the category catalog through the repository.
  Future<void> loadCategories() async {
    _isLoadingCategories = true;
    _categoriesError = null;
    notifyListeners();
    try {
      _categories = await _categoryRepository.getCategories();
      final selected = _selectedCategoryId;
      if (selected != null && !_categories.any((c) => c.id == selected)) {
        _selectedCategoryId = null;
      }
    } catch (_) {
      _categoriesError = 'No pudimos cargar las categorías. Intenta de nuevo.';
    }
    _isLoadingCategories = false;
    notifyListeners();
  }

  void selectCategory(int? categoryId) {
    _selectedCategoryId = categoryId;
    notifyListeners();
  }

  // --- Reservations snapshot ---

  /// Reloads the snapshot from the shared store (persisting any clock based
  /// transition such as the expiration of an unpaid reservation).
  Future<void> refresh() async {
    _snapshot = await _service.getReservations();
    notifyListeners();
  }

  /// The client's own reservations, most recent first, with the pending
  /// payment expiration already applied.
  List<Reservation> get reservations {
    final list = _service
        .resolveStatuses(_snapshot)
        .where((reservation) => reservation.guestId == userId)
        .toList();
    return List.unmodifiable(
      _service.sortReservations(
        list,
        field: ReservationSortField.createdAt,
        descending: true,
      ),
    );
  }

  List<String> get motelNames {
    final names = {
      for (final reservation in reservations) reservation.motelName,
    };
    return names.toList()..sort();
  }

  List<String> get roomLabelsFor =>
      reservations.map(_service.roomLabelOf).toSet().toList();

  /// Simulates the initial load (or manual refresh) of "Mis reservas".
  /// Exposes the `simulateError`/`simulateOffline` hooks to demonstrate the
  /// recoverable error and offline states deterministically.
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

    _snapshot = await _service.getReservations();
    _isLoading = false;
    notifyListeners();
  }

  List<Reservation> filteredReservations({
    String? motelName,
    String? roomLabel,
    ReservationSortField sortField = ReservationSortField.checkIn,
    bool descending = true,
  }) {
    final filtered = _service.filterReservations(
      reservations,
      motelName: motelName,
      roomLabel: roomLabel,
    );
    return _service.sortReservations(
      filtered,
      field: sortField,
      descending: descending,
    );
  }

  Reservation? getById(String id) {
    for (final reservation in reservations) {
      if (reservation.id == id) return reservation;
    }
    return null;
  }

  /// Motel completo asociado a una reserva. El widget de reseñas
  /// (`ReviewsSection`, del contexto `lib/views/review`) requiere el objeto
  /// `Motel` completo -no solo `motelId`- así que se delega en
  /// `MotelController` en vez de que la vista consulte otro contexto
  /// directamente.
  Future<Motel?> getMotelForReservation(Reservation reservation) {
    return _motelController.getMotelById(reservation.motelId);
  }

  // --- Availability and pricing (rules live in BookingService) ---

  /// Whether `[start, end)` is free for [roomId], according to every stored
  /// reservation, the preparation buffer and any external blocked range.
  bool isSlotAvailable(
    String roomId,
    DateTime start,
    DateTime end, {
    List<BlockedRange> externalBlocked = const [],
    String? excludingReservationId,
    bool roomIsActive = true,
  }) => _service.isSlotAvailable(
    _snapshot,
    roomId,
    start,
    end,
    externalBlocked: externalBlocked,
    excludingReservationId: excludingReservationId,
    roomIsActive: roomIsActive,
  );

  /// Explains why a slot is blocked, to show it when the user forces a slot
  /// that is not available.
  String explainBlockedSlot(
    String roomId,
    DateTime start,
    DateTime end, {
    List<BlockedRange> externalBlocked = const [],
    bool roomIsActive = true,
  }) => _service.explainBlockedSlot(
    _snapshot,
    roomId,
    start,
    end,
    externalBlocked: externalBlocked,
    roomIsActive: roomIsActive,
  );

  /// Message for the first booking rule broken by the schedule (or because
  /// the slot is taken), `null` if it can be booked.
  String? scheduleError(
    String roomId,
    DateTime checkIn,
    DateTime checkOut, {
    List<BlockedRange> externalBlocked = const [],
    bool roomIsActive = true,
  }) => _service.validateBooking(
    _snapshot,
    roomId,
    checkIn,
    checkOut,
    externalBlocked: externalBlocked,
    roomIsActive: roomIsActive,
  );

  /// Price of the stay (room, services, products and grand total).
  PriceBreakdown priceBreakdown({
    required int pricePerHour,
    DateTime? checkIn,
    DateTime? checkOut,
    List<ReservationLineItem> services = const [],
    List<ReservationLineItem> products = const [],
  }) => _service.calculatePrice(
    pricePerHour: pricePerHour,
    checkIn: checkIn,
    checkOut: checkOut,
    services: services,
    products: products,
  );

  // --- State changing actions ---

  /// Creates a `pending` reservation. Revalidates availability right before
  /// inserting and is idempotent by `requestId`.
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
    int? categoryId,
    List<BlockedRange> externalBlocked = const [],
    bool roomIsActive = true,
    bool simulateNetworkFailure = false,
    bool simulateConcurrentConflict = false,
  }) async {
    _errorMessage = null;
    notifyListeners();
    await Future<void>.delayed(const Duration(milliseconds: 500));

    // Idempotency: a retry of a request that was actually stored returns the
    // existing reservation instead of duplicating it.
    final existing = await _service.findByRequestId(requestId);
    if (existing != null) return CreateReservationResult.success(existing);

    if (simulateNetworkFailure &&
        _requestIdsWithSimulatedFailure.add(requestId)) {
      const message =
          'No fue posible conectar con el servidor. Puedes reintentar sin riesgo de duplicar tu reserva.';
      _errorMessage = message;
      notifyListeners();
      return const CreateReservationResult.networkError(message);
    }

    const concurrentMessage =
        'Ese horario acaba de ocuparse. Actualiza el calendario e intenta con otra franja.';
    if (simulateConcurrentConflict) {
      _errorMessage = concurrentMessage;
      notifyListeners();
      return const CreateReservationResult.conflict(concurrentMessage);
    }

    try {
      final reservation = await _service.createReservation(
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
        categoryId: categoryId,
        guestId: userId,
        guestName: 'Usuario demo',
        externalBlocked: externalBlocked,
        roomIsActive: roomIsActive,
      );
      await refresh();
      return CreateReservationResult.success(reservation);
    } on SlotUnavailableException catch (error) {
      _errorMessage = error.message;
      await refresh();
      return CreateReservationResult.conflict(error.message);
    }
  }

  /// Confirms the payment of a `pending` reservation (it becomes `upcoming`,
  /// or `active` if its check-in time was reached). Returns `false` when the
  /// reservation does not exist or is not pending (for example, it already
  /// expired).
  Future<bool> confirmPayment(
    String reservationId, {
    String paymentMethod = BookingService.defaultPaymentMethod,
  }) async {
    try {
      await Future<void>.delayed(const Duration(milliseconds: 400));
      await _service.confirmPayment(
        reservationId,
        paymentMethod: paymentMethod,
      );
    } on ReservationCancellationException {
      await refresh();
      return false;
    } on ReservationTransitionException {
      await refresh();
      return false;
    }
    await refresh();
    return true;
  }

  /// Cancels a client reservation. Only `pending` or `upcoming` ones can be
  /// cancelled; otherwise (blank reason, unknown id, other status) throws
  /// [ReservationCancellationException], the same contract the owner uses.
  Future<void> cancelReservation(String id, String reason) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    try {
      await _service.cancelReservation(id, reason);
    } finally {
      await refresh();
    }
  }

  // --- Pending payment expiration ---

  /// Time left before a `pending` reservation is cancelled for lack of
  /// payment. `null` if it does not apply anymore.
  Duration? remainingPendingTime(String reservationId) {
    final reservation = getById(reservationId);
    if (reservation == null) return null;
    return _service.remainingPendingTime(reservation);
  }

  /// Applies the pending payment expiration to the snapshot (and persists
  /// it), notifying listeners if some reservation changed.
  void checkExpirations() {
    final resolved = _service.resolveStatuses(_snapshot);
    var changed = false;
    for (var i = 0; i < resolved.length; i++) {
      if (resolved[i].status != _snapshot[i].status) changed = true;
    }
    if (!changed) return;
    _snapshot = resolved;
    notifyListeners();
    unawaited(_service.syncStatuses());
  }

  /// Starts a periodic expiration check owned by this controller (cancelled
  /// on [dispose]) so a screen with a countdown only has to listen to it.
  void startExpirationWatch({Duration interval = const Duration(seconds: 1)}) {
    _expirationTimer?.cancel();
    _expirationTimer = Timer.periodic(interval, (_) {
      checkExpirations();
      notifyListeners();
    });
  }
}
