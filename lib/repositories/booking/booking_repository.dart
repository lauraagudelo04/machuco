import 'package:machuco/database/app_database.dart';
import 'package:machuco/models/booking/booking.dart';
import 'package:machuco/models/booking/reservation_entity.dart';
import 'package:machuco/models/booking/reservation_line_item_entity.dart';
import 'package:machuco/repositories/booking/booking_seed_data.dart';
import 'package:machuco/repositories/booking/reservation_dao.dart';
import 'package:machuco/repositories/booking/reservation_mapper.dart';

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

/// Floor/SQLite backed implementation. Seeds the shared demo reservations
/// the first time it runs against an empty `reservations` table.
class FloorBookingRepository implements BookingRepository {
  FloorBookingRepository(this._dao, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final ReservationDao _dao;
  final DateTime Function() _now;
  Future<void>? _seeding;

  Future<void> _ensureSeeded() {
    return _seeding ??= _seed();
  }

  Future<void> _seed() async {
    final count = await _dao.countReservations() ?? 0;
    if (count > 0) return;
    for (final reservation in buildSeedReservations(_now())) {
      await _dao.insertReservation(
        ReservationMapper.toEntity(reservation),
        ReservationMapper.toLineItemEntities(reservation),
      );
    }
  }

  @override
  Future<List<Reservation>> getAll() async {
    await _ensureSeeded();
    final rows = await _dao.findAllReservations();
    final items = await _dao.findAllLineItems();
    final byReservation = <String, List<ReservationLineItemEntity>>{};
    for (final item in items) {
      (byReservation[item.reservationId] ??= []).add(item);
    }
    return List<Reservation>.unmodifiable([
      for (final row in rows)
        ReservationMapper.toDomain(row, byReservation[row.id] ?? const []),
    ]);
  }

  Future<Reservation> _hydrate(ReservationEntity row) async =>
      ReservationMapper.toDomain(row, await _dao.findLineItems(row.id));

  @override
  Future<Reservation?> getById(String id) async {
    await _ensureSeeded();
    final row = await _dao.findReservationById(id);
    return row == null ? null : _hydrate(row);
  }

  @override
  Future<Reservation?> findByRequestId(String requestId) async {
    await _ensureSeeded();
    final row = await _dao.findReservationByRequestId(requestId);
    return row == null ? null : _hydrate(row);
  }

  @override
  Future<void> add(Reservation reservation) async {
    await _ensureSeeded();
    await _dao.insertReservation(
      ReservationMapper.toEntity(reservation),
      ReservationMapper.toLineItemEntities(reservation),
    );
  }

  @override
  Future<void> update(Reservation reservation) async {
    await _ensureSeeded();
    if (await _dao.findReservationById(reservation.id) == null) return;
    await _dao.replaceReservation(
      ReservationMapper.toEntity(reservation),
      ReservationMapper.toLineItemEntities(reservation),
    );
  }
}

/// Opens the database lazily on first use, so app startup stays instant.
class LazyBookingRepository implements BookingRepository {
  LazyBookingRepository();

  Future<BookingRepository>? _delegate;

  Future<BookingRepository> _resolve() {
    return _delegate ??= AppDatabase.instance().then(
      (db) => FloorBookingRepository(db.reservationDao),
    );
  }

  @override
  Future<List<Reservation>> getAll() async => (await _resolve()).getAll();

  @override
  Future<Reservation?> getById(String id) async =>
      (await _resolve()).getById(id);

  @override
  Future<Reservation?> findByRequestId(String requestId) async =>
      (await _resolve()).findByRequestId(requestId);

  @override
  Future<void> add(Reservation reservation) async =>
      (await _resolve()).add(reservation);

  @override
  Future<void> update(Reservation reservation) async =>
      (await _resolve()).update(reservation);
}

/// Holds the repository controllers use by default: one shared instance so
/// every role sees the same reservations. Tests can replace [instance].
class BookingRepositoryProvider {
  const BookingRepositoryProvider._();

  static BookingRepository instance = InMemoryBookingRepository();

  /// Switches to the SQLite store. Called once from `main`; tests keep the
  /// in-memory default.
  static void useDatabase() {
    instance = LazyBookingRepository();
  }
}
