import 'package:floor/floor.dart';
import 'package:machuco/database/app_database.dart';
import 'package:machuco/database/model/owner/owner_entry.dart';
import 'package:machuco/models/auth/account_status.dart';
import 'package:machuco/models/owner_management/document_type.dart';
import 'package:machuco/models/owner_management/owner.dart';

@dao
abstract class OwnerDao {
  @Query('SELECT * FROM owners WHERE pendingDelete = 0 ORDER BY fullName ASC')
  Future<List<OwnerEntry>> findAll();

  @Query('SELECT * FROM owners WHERE id = :id LIMIT 1')
  Future<OwnerEntry?> findById(String id);

  @Query(
    'SELECT * FROM owners WHERE documentType = :documentType '
    'AND documentNumber = :documentNumber AND pendingDelete = 0 LIMIT 1',
  )
  Future<OwnerEntry?> findByDocument(
    String documentType,
    String documentNumber,
  );

  @Query('SELECT COUNT(*) FROM owners')
  Future<int?> count();

  /// Registros que aún no han viajado a la nube (`synchronized = 0`).
  @Query(
    'SELECT * FROM owners WHERE synchronized = 0 AND pendingDelete = 0 '
    'ORDER BY createdAt ASC',
  )
  Future<List<OwnerEntry>> findUnsynchronized();

  /// Registros eliminados localmente que aún existen en Firestore.
  @Query('SELECT * FROM owners WHERE pendingDelete = 1 ORDER BY createdAt ASC')
  Future<List<OwnerEntry>> findPendingDeletes();

  /// Marca una fila como confirmada por la nube.
  @Query('UPDATE owners SET synchronized = 1 WHERE id = :id')
  Future<void> markSynchronized(String id);

  /// Marca el borrado pendiente: la fila se oculta y deja de contar como alta.
  @Query('UPDATE owners SET pendingDelete = 1, synchronized = 0 WHERE id = :id')
  Future<void> markPendingDelete(String id);

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
  Future<List<Owner>> findUnsynchronized() async {
    final database = await _database;
    final entries = await database.ownerDao.findUnsynchronized();
    return entries.map(_toOwner).toList(growable: false);
  }

  /// Propietarios eliminados en este dispositivo que aún existen en la nube.
  Future<List<Owner>> findPendingDeletes() async {
    final database = await _database;
    final entries = await database.ownerDao.findPendingDeletes();
    return entries.map(_toOwner).toList(growable: false);
  }

  /// Confirma que la nube ya recibió el propietario.
  Future<void> markSynchronized(String id) async {
    final database = await _database;
    await database.ownerDao.markSynchronized(id);
  }

  /// Oculta la fila y la deja pendiente de borrar en Firestore.
  Future<void> markPendingDelete(String id) async {
    final database = await _database;
    await database.ownerDao.markPendingDelete(id);
  }

  /// Incorpora los propietarios que existen en la nube.
  ///
  /// Un cambio local pendiente (`synchronized = 0`) nunca se pisa: se subirá
  /// en el siguiente envío. Un borrado pendiente (`pendingDelete = 1`) tampoco
  /// se resucita: la fila se conserva hasta que Firestore confirme el delete.
  /// Los registros nuevos se insertan ya marcados como sincronizados para que
  /// no se vuelvan a enviar.
  Future<void> mergeRemoteOwners(List<Owner> owners) async {
    final database = await _database;
    for (final remote in owners) {
      final existing = await database.ownerDao.findById(remote.id);
      // Una cuenta anonimizada en la nube ya no es un propietario del módulo:
      // se quita la fila local (en este u otro dispositivo).
      if (remote.accountStatus == AccountStatus.anonymized) {
        if (existing != null) {
          await database.ownerDao.deleteById(remote.id);
        }
        continue;
      }
      if (existing == null) {
        await database.ownerDao.insertOwner(_toEntry(remote, synchronized: 1));
        continue;
      }
      if (existing.pendingDelete == 1) continue;
      if (existing.synchronized == 0) continue;
      await database.ownerDao.updateOwner(
        _toEntry(remote, synchronized: 1, createdAt: existing.createdAt),
      );
    }
  }

  Future<void> insert(Owner owner) async {
    final database = await _database;
    await database.ownerDao.insertOwner(_toEntry(owner));
  }

  /// Inserta un propietario que ya existe en la nube (recién creado con su
  /// cuenta de Firebase Auth), por lo que nace sincronizado.
  Future<void> insertSynchronized(Owner owner) async {
    final database = await _database;
    await database.ownerDao.insertOwner(_toEntry(owner, synchronized: 1));
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
        countryCode: owner.countryCode,
        countryName: owner.countryName,
        address: owner.address,
        isActive: owner.isActive ? 1 : 0,
        synchronized: 0,
        accountStatus: owner.accountStatus?.storageValue,
        pendingDelete: existing.pendingDelete,
        createdAt: existing.createdAt,
        updatedAt: DateTime.now(),
      ),
    );
  }

  Future<void> deleteById(String id) async {
    final database = await _database;
    await database.ownerDao.deleteById(id);
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
    countryCode: entry.countryCode,
    countryName: entry.countryName,
    address: entry.address,
    isActive: entry.isActive == 1,
    accountStatus: accountStatusFromStorage(entry.accountStatus),
    isSynchronized: entry.synchronized == 1,
  );

  /// Al crear, el registro nace con la marca `synchronized = 0` (pendiente
  /// de enviar a la nube) y con las marcas de tiempo de ahora.
  OwnerEntry _toEntry(
    Owner owner, {
    int synchronized = 0,
    int pendingDelete = 0,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    final now = DateTime.now();
    return OwnerEntry(
      id: owner.id,
      fullName: owner.fullName,
      documentType: owner.documentType.name,
      documentNumber: owner.documentNumber,
      email: owner.email,
      phone: owner.phone,
      countryCode: owner.countryCode,
      countryName: owner.countryName,
      address: owner.address,
      isActive: owner.isActive ? 1 : 0,
      synchronized: synchronized,
      accountStatus: owner.accountStatus?.storageValue,
      pendingDelete: pendingDelete,
      createdAt: createdAt ?? now,
      updatedAt: updatedAt ?? now,
    );
  }
}
