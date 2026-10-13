import 'package:floor/floor.dart';
import 'package:machuco/models/booking/reservation_category.dart';

@dao
abstract class ReservationCategoryDao {
  @Query('SELECT * FROM reservation_categories ORDER BY name ASC')
  Future<List<ReservationCategory>> findAll();

  @Query('SELECT * FROM reservation_categories WHERE id = :id LIMIT 1')
  Future<ReservationCategory?> findById(int id);

  @Insert(onConflict: OnConflictStrategy.ignore)
  Future<void> insertAll(List<ReservationCategory> categories);

  @Insert(onConflict: OnConflictStrategy.ignore)
  Future<void> insertCategory(ReservationCategory category);
}
