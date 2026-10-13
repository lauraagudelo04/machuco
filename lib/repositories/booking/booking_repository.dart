import 'package:machuco/models/booking/booking.dart';
import 'package:machuco/repositories/booking/booking_seed_data.dart';

/// Storage access for reservations. Controllers and the booking service
/// depend on this interface only, so a persistent implementation (for
/// example Floor) can replace the in-memory one without touching them.
///
/// Every method is asynchronous on purpose, even though the in-memory
/// implementation resolves immediately.
abstract class BookingRepository {
  /// All reservations, in no particular order.
  Future<List<Reservation>> getAll();

  Future<Reservation?> getById(String id);

  Future<Reservation?> findByRequestId(String requestId);

  Future<void> add(Reservation reservation);

  /// Replaces the stored reservation that has the same id as
  /// [reservation]. Does nothing if it does not exist.
  Future<void> update(Reservation reservation);
}

/// In-memory implementation holding the one shared reservation list that
/// client, owner and system admin read and write.
class InMemoryBookingRepository implements BookingRepository {
  /// Creates a store pre-filled with the shared seed (relative to [now]) or
  /// with [initial] when given (handy for tests).
  InMemoryBookingRepository({
    DateTime Function()? now,
    List<Reservation>? initial,
  }) : _reservations = List<Reservation>.of(
         initial ?? buildSeedReservations((now ?? DateTime.now)()),
       );

  final List<Reservation> _reservations;

  @override
  Future<List<Reservation>> getAll() async =>
      List<Reservation>.unmodifiable(_reservations);

  @override
  Future<Reservation?> getById(String id) async {
    for (final reservation in _reservations) {
      if (reservation.id == id) return reservation;
    }
    return null;
  }

  @override
  Future<Reservation?> findByRequestId(String requestId) async {
    for (final reservation in _reservations) {
      if (reservation.requestId == requestId) return reservation;
    }
    return null;
  }

  @override
  Future<void> add(Reservation reservation) async {
    _reservations.add(reservation);
  }

  @override
  Future<void> update(Reservation reservation) async {
    final index = _reservations.indexWhere((r) => r.id == reservation.id);
    if (index == -1) return;
    _reservations[index] = reservation;
  }
}

/// Holds the repository controllers use by default: one shared instance so
/// every role sees the same reservations. Tests can replace [instance].
class BookingRepositoryProvider {
  const BookingRepositoryProvider._();

  static BookingRepository instance = InMemoryBookingRepository();
}
