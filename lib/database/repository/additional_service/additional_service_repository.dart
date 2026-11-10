import 'package:machuco/database/app_database.dart';
import 'package:machuco/database/repository/additional_service/additional_service_dao.dart';
import 'package:machuco/models/additional_service/additional_service.dart';
import 'package:machuco/models/additional_service/additional_service_entry.dart';

class AdditionalServiceRepository {
  AdditionalServiceRepository({AppDatabase? database})
    : _database = database == null
          ? AppDatabaseProvider.database
          : Future.value(database);

  final Future<AppDatabase> _database;

  Future<AdditionalServiceDao> _dao() async {
    final db = await _database;
    return db.additionalServiceDao;
  }

  Future<List<AdditionalService>> findByMotel(String motelId) async {
    final dao = await _dao();
    final entries = await dao.findByMotel(motelId);
    return entries.map((e) => e.toService()).toList(growable: false);
  }

  Future<List<AdditionalService>> findAll() async {
    final dao = await _dao();
    final entries = await dao.findAll();
    return entries.map((e) => e.toService()).toList(growable: false);
  }

  Future<void> saveAll(List<AdditionalService> services) async {
    final dao = await _dao();
    if (services.isEmpty) {
      await dao.deleteAll();
      return;
    }
    await dao.deleteAll();
    await dao.insertAll(
      services.map(AdditionalServiceEntry.fromService).toList(),
    );
  }

  /// Reemplaza la copia local de un motel por [services] (la caché de lo que
  /// hay en Firestore) sin tocar los servicios de otros moteles.
  Future<void> replaceForMotel(
    String motelId,
    List<AdditionalService> services,
  ) async {
    final dao = await _dao();
    final current = await dao.findByMotel(motelId);
    for (final entry in current) {
      await dao.deleteById(entry.id);
    }
    if (services.isEmpty) return;
    await dao.insertAll(
      services.map(AdditionalServiceEntry.fromService).toList(),
    );
  }

  Future<void> insertService(AdditionalService service) async {
    final dao = await _dao();
    await dao.insertAll([AdditionalServiceEntry.fromService(service)]);
  }

  Future<void> updateService(AdditionalService service) async {
    final dao = await _dao();
    await dao.updateService(AdditionalServiceEntry.fromService(service));
  }

  Future<void> deleteService(String serviceId) async {
    final dao = await _dao();
    await dao.deleteById(serviceId);
  }
}
