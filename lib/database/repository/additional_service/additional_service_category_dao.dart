import 'package:floor/floor.dart';
import 'package:machuco/models/additional_service/additional_service_category.dart';

/// Data Access Object del maestro de categorías sobre SQLite.
@dao
abstract class AdditionalServiceCategoryDao {
  @Query('SELECT * FROM additional_service_categories ORDER BY name ASC')
  Future<List<AdditionalServiceCategory>> findAll();

  @Query('SELECT COUNT(*) FROM additional_service_categories')
  Future<int?> count();

  @insert
  Future<void> insertAll(List<AdditionalServiceCategory> categories);

  @Query('DELETE FROM additional_service_categories')
  Future<void> deleteAll();
}
