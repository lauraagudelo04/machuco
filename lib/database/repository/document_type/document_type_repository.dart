import 'package:floor/floor.dart';
import 'package:machuco/database/app_database.dart';
import 'package:machuco/database/model/document_type/document_type_entry.dart';
import 'package:machuco/models/owner_management/document_type.dart';

@dao
abstract class DocumentTypeDao {
  @Query(
    'SELECT * FROM document_types WHERE isActive = 1 ORDER BY sortOrder ASC',
  )
  Future<List<DocumentTypeEntry>> findActive();

  @Query('SELECT * FROM document_types ORDER BY sortOrder ASC')
  Future<List<DocumentTypeEntry>> findAll();
}

class DocumentTypeRepositoryException implements Exception {
  const DocumentTypeRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Acceso al maestro local de tipos de documento.
///
/// Traduce las filas de `document_types` a los valores de [DocumentType]. Las
/// filas cuyo [DocumentTypeEntry.code] ya no existe en el enum se ignoran para
/// no romper el selector tras un despliegue parcial.
class DocumentTypeRepository {
  DocumentTypeRepository({AppDatabase? database})
    : _database = database == null
          ? AppDatabaseProvider.database
          : Future.value(database);

  final Future<AppDatabase> _database;

  Future<List<DocumentType>> findActive() async {
    final database = await _database;
    final entries = await database.documentTypeDao.findActive();
    return [
      for (final entry in entries)
        if (DocumentType.fromCode(entry.code) case final type?) type,
    ];
  }
}
