import 'package:flutter_test/flutter_test.dart';
import 'package:machuco/controllers/booking/client_view/client_booking_controller.dart';
import 'package:machuco/controllers/booking/owner_view/owner_booking_controller.dart';
import 'package:machuco/controllers/booking/system_admin_view/system_admin_booking_controller.dart';
import 'package:machuco/models/booking/booking.dart';
import 'package:machuco/models/booking/reservation_category.dart';
import 'package:machuco/repositories/booking/reservation_category_repository.dart';

class _FailingRepository implements ReservationCategoryRepository {
  @override
  Future<List<ReservationCategory>> getCategories() async =>
      throw Exception('db unavailable');

  @override
  Future<ReservationCategory?> getCategoryById(int id) async => null;
}

void main() {
  const repository = InMemoryReservationCategoryRepository();

  group('ClientBookingController categories', () {
    test('loads categories through the repository', () async {
      final controller = ClientBookingController(
        categoryRepository: repository,
      );

      await controller.loadCategories();

      expect(controller.categories, isNotEmpty);
      expect(controller.categoriesError, isNull);
      expect(controller.isLoadingCategories, isFalse);
    });

    test('exposes an error state when loading fails', () async {
      final controller = ClientBookingController(
        categoryRepository: _FailingRepository(),
      );

      await controller.loadCategories();

      expect(controller.categories, isEmpty);
      expect(controller.categoriesError, isNotNull);
    });

    test('selection is required and can be cleared', () async {
      final controller = ClientBookingController(
        categoryRepository: repository,
      );
      await controller.loadCategories();

      expect(controller.hasCategorySelected, isFalse);
      controller.selectCategory(controller.categories.first.id);
      expect(controller.hasCategorySelected, isTrue);
      controller.selectCategory(null);
      expect(controller.hasCategorySelected, isFalse);
    });

    test('createReservation persists the categoryId', () async {
      final controller = ClientBookingController(
        categoryRepository: repository,
      );
      final now = DateTime.now();

      final result = await controller.createReservation(
        requestId: 'req-category-1',
        motelId: 'motel-category-test',
        motelName: 'Motel Prueba',
        roomId: 'room-category-test',
        roomName: 'Suite Prueba',
        roomNumber: '901',
        checkIn: now.add(const Duration(days: 20)),
        checkOut: now.add(const Duration(days: 20, hours: 3)),
        stayMode: StayMode.dateWithHourBlock,
        guestCount: 2,
        services: const [],
        products: const [],
        roomTotal: 90000,
        categoryId: 3,
      );

      expect(result.reservation!.categoryId, 3);
    });
  });

  group('OwnerBookingController category filter', () {
    test('filters reservations by categoryId', () async {
      final controller = OwnerBookingController(categoryRepository: repository);
      await controller.loadReservations();

      expect(controller.categories, isNotEmpty);
      final all = await controller.filteredReservations();
      final filtered = await controller.filteredReservations(categoryId: 1);

      expect(filtered, isNotEmpty);
      expect(filtered.length, lessThan(all.length));
      expect(filtered.every((r) => r.categoryId == 1), isTrue);
    });
  });

  group('SystemAdminBookingController category filter', () {
    test('evolution counts only reservations of the category', () async {
      final controller = SystemAdminBookingController(
        categoryRepository: repository,
      );

      int total(List<Map<String, dynamic>> series) =>
          series.fold(0, (sum, p) => sum + (p['value'] as int));

      final all = total(await controller.reservationsEvolution('1'));
      final byCategory = total(
        await controller.reservationsEvolution('1', categoryId: 1),
      );

      expect(byCategory, greaterThan(0));
      expect(byCategory, lessThan(all));
    });
  });
}
