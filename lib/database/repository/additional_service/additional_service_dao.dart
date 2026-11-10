import 'package:floor/floor.dart';
import 'package:machuco/models/additional_service/additional_service_entry.dart';

/// Data Access Object de servicios adicionales sobre SQLite.
@dao
abstract class AdditionalServiceDao {
  @Query('SELECT * FROM additional_services ORDER BY name ASC')
  Future<List<AdditionalServiceEntry>> findAll();

  @Query(
    'SELECT * FROM additional_services WHERE motelId = :motelId ORDER BY name ASC',
  )
  Future<List<AdditionalServiceEntry>> findByMotel(String motelId);

  @Query('SELECT COUNT(*) FROM additional_services')
  Future<int?> count();

  @insert
  Future<void> insertAll(List<AdditionalServiceEntry> services);

  @update
  Future<void> updateService(AdditionalServiceEntry service);

  @Query('DELETE FROM additional_services WHERE id = :serviceId')
  Future<void> deleteById(String serviceId);

  @Query('DELETE FROM additional_services')
  Future<void> deleteAll();
}
