import 'package:floor/floor.dart';
import 'package:machuco/database/model/pqrs_type/pqrs_type_entry.dart';

@dao
abstract class PqrsTypeDao {
  @Query('SELECT * FROM pqrs_types ORDER BY sortOrder ASC, id ASC')
  Future<List<PqrsTypeEntry>> findAll();

  @Insert(onConflict: OnConflictStrategy.replace)
  Future<void> insertAll(List<PqrsTypeEntry> types);

  @Query('DELETE FROM pqrs_types')
  Future<void> deleteAll();

  /// Replaces the cache with the full response, so a withdrawn type
  /// disappears.
  @transaction
  Future<void> replaceAll(List<PqrsTypeEntry> types) async {
    await deleteAll();
    await insertAll(types);
  }
}
