import 'package:machuco/database/app_database.dart';
import 'package:machuco/models/booking/reservation_category.dart';
import 'package:machuco/repositories/booking/reservation_category_dao.dart';
import 'package:machuco/repositories/booking/supabase_reservation_category_source.dart';
import 'package:machuco/service/room/supabase_room_config.dart';

/// Offline fallback for the reservation category catalog. Must match the
/// Supabase seed in `supabase/migrations/202611070001_create_reservation_categories.sql`.
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
  /// All categories ordered by name. Syncs the master (or seeds the
  /// fallback) on first use.
  Future<List<ReservationCategory>> getCategories();

  Future<ReservationCategory?> getCategoryById(int id);
}

/// Floor/SQLite cache of the Supabase master. On first use it refreshes the
/// cache from [fetchRemote]; when the master is unreachable or empty it keeps
/// the cache, seeding [defaultReservationCategories] if the cache is empty.
class FloorReservationCategoryRepository
    implements ReservationCategoryRepository {
  FloorReservationCategoryRepository(this._dao, {this.fetchRemote});

  final ReservationCategoryDao _dao;
  final Future<List<ReservationCategory>> Function()? fetchRemote;
  Future<void>? _syncing;

  Future<void> _ensureSynced() {
    final syncing = _syncing ??= _sync();
    // A failed sync must not stay memoized, so the next call retries.
    return syncing.catchError((Object error) {
      _syncing = null;
      throw error;
    });
  }

  Future<void> _sync() async {
    final remote = await _fetchRemoteOrNull();
    if (remote != null && remote.isNotEmpty) {
      await _dao.upsertAll(remote);
      return;
    }
    if ((await _dao.findAll()).isEmpty) {
      await _dao.insertAll(defaultReservationCategories);
    }
  }

  /// Offline or misconfigured Supabase is not an error: the cache is used.
  Future<List<ReservationCategory>?> _fetchRemoteOrNull() async {
    final fetch = fetchRemote;
    if (fetch == null) return null;
    try {
      return await fetch();
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<ReservationCategory>> getCategories() async {
    await _ensureSynced();
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
    return _delegate ??= AppDatabaseProvider.database.then(
      (db) => FloorReservationCategoryRepository(
        db.reservationCategoryDao,
        fetchRemote: SupabaseRoomConfig.isConfigured
            ? SupabaseReservationCategorySource(
                baseUrl: SupabaseRoomConfig.baseUrl,
                apiKey: SupabaseRoomConfig.apiKey,
              ).fetchAll
            : null,
      ),
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
