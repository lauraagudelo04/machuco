import 'package:floor/floor.dart';
import 'package:machuco/database/model/image_format/allowed_image_format_entry.dart';

@dao
abstract class AllowedImageFormatDao {
  @Query('SELECT * FROM allowed_image_formats ORDER BY id ASC')
  Future<List<AllowedImageFormatEntry>> findAll();

  @Insert(onConflict: OnConflictStrategy.replace)
  Future<void> insertAll(List<AllowedImageFormatEntry> formats);

  @Query('DELETE FROM allowed_image_formats')
  Future<void> deleteAll();

  /// Replaces the cache with the full response, so a withdrawn format
  /// disappears.
  @transaction
  Future<void> replaceAll(List<AllowedImageFormatEntry> formats) async {
    await deleteAll();
    await insertAll(formats);
  }
}
