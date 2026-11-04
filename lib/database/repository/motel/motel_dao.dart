import 'package:floor/floor.dart';
import 'package:machuco/database/model/motel/motel_entity.dart';

@dao
abstract class MotelDao {
  @Query('SELECT * FROM motels ORDER BY name ASC')
  Future<List<MotelEntity>> findAll();

  @Query('SELECT * FROM motels WHERE id = :id')
  Future<MotelEntity?> findById(String id);

  @Insert(onConflict: OnConflictStrategy.replace)
  Future<void> upsert(MotelEntity motel);

  @Insert(onConflict: OnConflictStrategy.replace)
  Future<void> upsertAll(List<MotelEntity> motels);

  @Query('DELETE FROM motels')
  Future<void> deleteAll();

  @transaction
  Future<void> replaceAll(List<MotelEntity> motels) async {
    await deleteAll();
    await upsertAll(motels);
  }
}
