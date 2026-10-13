import 'package:flutter_test/flutter_test.dart';
import 'package:machuco/models/booking/reservation_category.dart';
import 'package:machuco/repositories/booking/reservation_category_dao.dart';
import 'package:machuco/repositories/booking/reservation_category_repository.dart';

class _FakeDao implements ReservationCategoryDao {
  _FakeDao([List<ReservationCategory> initial = const []])
    : rows = List.of(initial);

  final List<ReservationCategory> rows;
  int insertAllCalls = 0;
  bool failInsert = false;

  @override
  Future<List<ReservationCategory>> findAll() async =>
      List.of(rows)..sort((a, b) => a.name.compareTo(b.name));

  @override
  Future<ReservationCategory?> findById(int id) async {
    for (final row in rows) {
      if (row.id == id) return row;
    }
    return null;
  }

  @override
  Future<void> insertAll(List<ReservationCategory> categories) async {
    insertAllCalls++;
    if (failInsert) throw StateError('seed failed');
    rows.addAll(categories);
  }

  @override
  Future<void> insertCategory(ReservationCategory category) async =>
      rows.add(category);
}

void main() {
  group('FloorReservationCategoryRepository', () {
    test('seeds the default catalog when the table is empty', () async {
      final dao = _FakeDao();
      final repository = FloorReservationCategoryRepository(dao);

      final categories = await repository.getCategories();

      expect(categories.length, defaultReservationCategories.length);
      expect(dao.insertAllCalls, 1);
      expect(
        categories.map((c) => c.name).toList(),
        categories.map((c) => c.name).toList()..sort(),
      );
    });

    test('does not seed again when the catalog already has rows', () async {
      final dao = _FakeDao(const [ReservationCategory(id: 9, name: 'Custom')]);
      final repository = FloorReservationCategoryRepository(dao);

      await repository.getCategories();
      await repository.getCategories();

      expect(dao.insertAllCalls, 0);
      expect(dao.rows.length, 1);
    });

    test('seeds only once across repeated reads', () async {
      final dao = _FakeDao();
      final repository = FloorReservationCategoryRepository(dao);

      await repository.getCategories();
      await repository.getCategories();

      expect(dao.insertAllCalls, 1);
    });

    test('concurrent reads seed once', () async {
      final dao = _FakeDao();
      final repository = FloorReservationCategoryRepository(dao);

      await Future.wait([
        repository.getCategories(),
        repository.getCategories(),
        repository.getCategoryById(1),
      ]);

      expect(dao.insertAllCalls, 1);
      expect(dao.rows.length, defaultReservationCategories.length);
    });

    test('a failed seed is retried on the next call', () async {
      final dao = _FakeDao()..failInsert = true;
      final repository = FloorReservationCategoryRepository(dao);

      await expectLater(repository.getCategories(), throwsStateError);
      dao.failInsert = false;
      final categories = await repository.getCategories();

      expect(categories.length, defaultReservationCategories.length);
      expect(dao.insertAllCalls, 2);
    });

    test('getCategoryById returns the row or null', () async {
      final repository = FloorReservationCategoryRepository(_FakeDao());

      expect((await repository.getCategoryById(3))?.name, 'Suite');
      expect(await repository.getCategoryById(999), isNull);
    });
  });
}
