import 'package:machuco/database/app_database.dart';
import 'package:machuco/models/booking/reservation_category.dart';
import 'package:machuco/repositories/booking/reservation_category_dao.dart';

/// Single seed source for the reservation category catalog.
const List<ReservationCategory> defaultReservationCategories = [
  ReservationCategory(id: 1, name: 'Sencilla'),
  ReservationCategory(id: 2, name: 'Doble'),
  ReservationCategory(id: 3, name: 'Suite'),
  ReservationCategory(id: 4, name: 'Jacuzzi'),
  ReservationCategory(id: 5, name: 'Temática'),
];

/// Read access to the reservation category catalog. Controllers depend on
/// this interface so they never touch the DAO or the database directly.
abstract class ReservationCategoryRepository {
  /// All categories ordered by name. Seeds the catalog when it is empty.
  Future<List<ReservationCategory>> getCategories();

  Future<ReservationCategory?> getCategoryById(int id);
}

/// Floor/SQLite backed implementation.
class FloorReservationCategoryRepository
    implements ReservationCategoryRepository {
  FloorReservationCategoryRepository(this._dao);

  final ReservationCategoryDao _dao;
  Future<void>? _seeding;

  Future<void> _ensureSeeded() {
    final seeding = _seeding ??= _seed();
    // A failed seed must not stay memoized, so the next call retries.
    return seeding.catchError((Object error) {
      _seeding = null;
      throw error;
    });
  }

  Future<void> _seed() async {
    if ((await _dao.findAll()).isEmpty) {
      await _dao.insertAll(defaultReservationCategories);
    }
  }

  @override
  Future<List<ReservationCategory>> getCategories() async {
    await _ensureSeeded();
    return _dao.findAll();
  }

  @override
  Future<ReservationCategory?> getCategoryById(int id) async {
    await getCategories();
    return _dao.findById(id);
  }
}

/// Opens the database lazily on first use, so app startup stays instant.
class LazyReservationCategoryRepository
    implements ReservationCategoryRepository {
  LazyReservationCategoryRepository();

  Future<ReservationCategoryRepository>? _delegate;

  Future<ReservationCategoryRepository> _resolve() {
    return _delegate ??= AppDatabase.instance().then(
      (db) => FloorReservationCategoryRepository(db.reservationCategoryDao),
    );
  }

  @override
  Future<List<ReservationCategory>> getCategories() async =>
      (await _resolve()).getCategories();

  @override
  Future<ReservationCategory?> getCategoryById(int id) async =>
      (await _resolve()).getCategoryById(id);
}

/// In-memory implementation backed by the seed list. Default for
/// controllers when no database has been wired, and usable as a fake.
class InMemoryReservationCategoryRepository
    implements ReservationCategoryRepository {
  const InMemoryReservationCategoryRepository([
    this._categories = defaultReservationCategories,
  ]);

  final List<ReservationCategory> _categories;

  @override
  Future<List<ReservationCategory>> getCategories() async {
    final sorted = List<ReservationCategory>.from(_categories)
      ..sort((a, b) => a.name.compareTo(b.name));
    return sorted;
  }

  @override
  Future<ReservationCategory?> getCategoryById(int id) async {
    for (final category in _categories) {
      if (category.id == id) return category;
    }
    return null;
  }
}

/// Holds the repository controllers use by default. Tests keep the
/// in-memory default; `main` switches to the database at startup.
class ReservationCategoryRepositoryProvider {
  const ReservationCategoryRepositoryProvider._();

  static ReservationCategoryRepository instance =
      const InMemoryReservationCategoryRepository();

  static void useDatabase() {
    instance = LazyReservationCategoryRepository();
  }
}
