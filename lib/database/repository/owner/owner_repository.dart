import 'package:floor/floor.dart';
import 'package:machuco/database/app_database.dart';
import 'package:machuco/database/model/owner/owner_entry.dart';
import 'package:machuco/models/owner_management/document_type.dart';
import 'package:machuco/models/owner_management/owner.dart';

@dao
abstract class OwnerDao {
  @Query('SELECT * FROM owners ORDER BY fullName ASC')
  Future<List<OwnerEntry>> findAll();

  @Query('SELECT * FROM owners WHERE id = :id LIMIT 1')
  Future<OwnerEntry?> findById(String id);

  @Query(
    'SELECT * FROM owners WHERE documentType = :documentType '
    'AND documentNumber = :documentNumber LIMIT 1',
  )
  Future<OwnerEntry?> findByDocument(
    String documentType,
    String documentNumber,
  );

  @Query('SELECT COUNT(*) FROM owners')
  Future<int?> count();

  /// Registros que aún no han viajado a la nube (`synchronized = 0`).
  @Query('SELECT * FROM owners WHERE synchronized = 0 ORDER BY createdAt ASC')
  Future<List<OwnerEntry>> findUnsynchronized();

  @insert
  Future<void> insertOwner(OwnerEntry owner);

  @update
  Future<void> updateOwner(OwnerEntry owner);

  @Query('DELETE FROM owners WHERE id = :id')
  Future<void> deleteById(String id);
}

class OwnerRepositoryException implements Exception {
  const OwnerRepositoryException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Acceso a datos del módulo de propietarios sobre la base local (Floor).
///
/// Concentra el mapeo `OwnerEntry` (fila) <-> `Owner` (dominio) para que el
/// service y el controlador trabajen sólo con el modelo de dominio.
class OwnerRepository {
  OwnerRepository({AppDatabase? database})
    : _database = database == null
          ? AppDatabaseProvider.database
          : Future.value(database);

  final Future<AppDatabase> _database;

  /// Todos los propietarios ordenados por nombre.
  Future<List<Owner>> findAll() async {
    final database = await _database;
    final entries = await database.ownerDao.findAll();
    return entries.map(_toOwner).toList(growable: false);
  }

  /// Propietario por identificador, o `null` si no existe.
  Future<Owner?> findById(String id) async {
    final database = await _database;
    final entry = await database.ownerDao.findById(id);
    return entry == null ? null : _toOwner(entry);
  }

  /// Indica si ya hay un propietario registrado con ese documento.
  Future<bool> existsByDocument(DocumentType type, String number) async {
    final database = await _database;
    final entry = await database.ownerDao.findByDocument(type.name, number);
    return entry != null;
  }

  /// Propietarios que todavía no se han enviado a la nube.
  ///
  /// Será la fuente del proceso de sincronización cuando exista el backend.
  Future<List<Owner>> findUnsynchronized() async {
    final database = await _database;
    final entries = await database.ownerDao.findUnsynchronized();
    return entries.map(_toOwner).toList(growable: false);
  }

  Future<void> insert(Owner owner) async {
    final database = await _database;
    await database.ownerDao.insertOwner(_toEntry(owner));
  }

  Future<void> update(Owner owner) async {
    final database = await _database;
    final existing = await database.ownerDao.findById(owner.id);
    if (existing == null) {
      throw const OwnerRepositoryException('El propietario ya no existe.');
    }
    // Floor reemplaza la fila completa, así que se conserva la fecha de
    // registro original y sólo se refresca la de última modificación.
    await database.ownerDao.updateOwner(
      OwnerEntry(
        id: owner.id,
        fullName: owner.fullName,
        documentType: owner.documentType.name,
        documentNumber: owner.documentNumber,
        email: owner.email,
        phone: owner.phone,
        address: owner.address,
        isActive: owner.isActive ? 1 : 0,
        synchronized: 0,
        createdAt: existing.createdAt,
        updatedAt: DateTime.now(),
      ),
    );
  }

  Future<void> deleteById(String id) async {
    final database = await _database;
    await database.ownerDao.deleteById(id);
  }

  /// Inserta los datos semilla sólo si la tabla está vacía.
  Future<void> seedIfEmpty(List<Owner> seeds) async {
    final database = await _database;
    final total = await database.ownerDao.count() ?? 0;
    if (total > 0) return;
    for (final seed in seeds) {
      await database.ownerDao.insertOwner(_toEntry(seed));
    }
  }

  Owner _toOwner(OwnerEntry entry) => Owner(
    id: entry.id,
    fullName: entry.fullName,
    documentType: DocumentType.values.firstWhere(
      (type) => type.name == entry.documentType,
      orElse: () => DocumentType.citizenshipCard,
    ),
    documentNumber: entry.documentNumber,
    email: entry.email,
    phone: entry.phone,
    address: entry.address,
    isActive: entry.isActive == 1,
    isSynchronized: entry.synchronized == 1,
  );

  /// Al crear, el registro nace con la marca `synchronized = 0` (pendiente
  /// de enviar a la nube) y con las marcas de tiempo de ahora.
  OwnerEntry _toEntry(Owner owner) {
    final now = DateTime.now();
    return OwnerEntry(
      id: owner.id,
      fullName: owner.fullName,
      documentType: owner.documentType.name,
      documentNumber: owner.documentNumber,
      email: owner.email,
      phone: owner.phone,
      address: owner.address,
      isActive: owner.isActive ? 1 : 0,
      synchronized: 0,
      createdAt: now,
      updatedAt: now,
    );
  }
}
