/// Data Access Object para la entidad [Owner].
///
/// Encapsula todas las sentencias SQL relacionadas con la tabla `owners`.
/// Almacenamiento caché/transitorio. Versión del esquema: 1.
/// El campo `phone` es un string con formato internacional (ej. +57 300 123 4567).

import 'package:sqflite/sqflite.dart';
import 'package:machuco/models/owner_management/owner.dart';
import 'package:machuco/models/owner_management/document_type.dart';
import 'sqlite_database.dart';

class OwnerDao {
  OwnerDao._();

  static final OwnerDao instance = OwnerDao._();

  /// Versión del esquema. Incrementar al cambiar la estructura de la tabla.
  static const int schemaVersion = 1;

  /// Crea la tabla si no existe (se invoca desde database_config.dart onCreate).
  static const String createTableSql = '''
    CREATE TABLE IF NOT EXISTS owners (
      id TEXT PRIMARY KEY,
      full_name TEXT NOT NULL,
      document_type TEXT NOT NULL,
      document_number TEXT NOT NULL,
      email TEXT NOT NULL,
      phone TEXT NOT NULL,
      address TEXT NOT NULL,
      is_active INTEGER NOT NULL DEFAULT 1,
      synchronized INTEGER NOT NULL DEFAULT 0,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL
    )
  ''';

  Future<Database> get _db => SQLiteDatabase.instance.database;

  /// Inserta un nuevo propietario.
  Future<int> insert(Owner owner) async {
    final db = await _db;
    // Mapeo manual de campos al SQL, sin depender de toMap/fromMap del modelo.
    final sql = '''
      INSERT INTO owners (id, full_name, documento_tipo, documento_numero, email, telefono, direccion, activo, sincronizado, creado, actualizado)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''';
    final List<dynamic> args = [
      owner.id,
      owner.fullName,
      owner.documentType.name,
      owner.documentNumber,
      owner.email,
      owner.phone,
      owner.address,
      owner.isActive ? 1 : 0,
      0,
      DateTime.now().millisecondsSinceEpoch,
      DateTime.now().millisecondsSinceEpoch,
    ];
    return await db.rawInsert(sql, args);
  }

  /// Actualiza un propietario existente.
  Future<int> update(Owner owner) async {
    final db = await _db;
    final sql = '''
      UPDATE owners
      SET full_name = ?, documento_tipo = ?, documento_numero = ?, email = ?, telefono = ?, direccion = ?, activo = ?, actualizado = ?
      WHERE id = ?
    ''';
    final List<dynamic> args = [
      owner.fullName,
      owner.documentType.name,
      owner.documentNumber,
      owner.email,
      owner.phone,
      owner.address,
      owner.isActive ? 1 : 0,
      DateTime.now().millisecondsSinceEpoch,
      owner.id,
    ];
    return await db.rawUpdate(sql, args);
  }

  /// Elimina un propietario por ID.
  Future<int> delete(String id) async {
    final db = await _db;
    return await db.delete('owners', where: 'id = ?', whereArgs: [id]);
  }

  /// Obtiene un propietario por ID.
  Future<Owner?> getById(String id) async {
    final db = await _db;
    final List<Map<String, dynamic>> maps = await db.query(
      'owners',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return _mapToOwner(maps.first);
  }

  /// Obtiene todos los propietarios, ordenados por nombre.
  Future<List<Owner>> getAll({bool onlyActive = false}) async {
    final db = await _db;
    final cond = onlyActive ? 'is_active = 1' : null;
    final List<Map<String, dynamic>> maps = await db.query(
      'owners',
      where: cond,
      orderBy: 'full_name ASC',
    );
    return maps.map(_mapToOwner).toList();
  }

  /// Busca propietarios por nombre, documento o email (contiene, case-insensitive).
  Future<List<Owner>> search(String query) async {
    final db = await _db;
    final like = '%${query.toLowerCase()}%';
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT * FROM owners
      WHERE LOWER(full_name) LIKE ? OR LOWER(document_number) LIKE ? OR LOWER(email) LIKE ?
    ORDER BY full_name ASC''', [like, like, like]);
    return maps.map(_mapToOwner).toList();
  }

  /// Obtiene propietarios que no se han sincronizado con la nube.
  Future<List<Owner>> getUnsynchronized() async {
    final db = await _db;
    final List<Map<String, dynamic>> maps = await db.query(
      'owners',
      where: 'synchronized = 0',
      orderBy: 'created_at ASC',
    );
    return maps.map(_mapToOwner).toList();
  }

  /// Marca un propietario como sincronizado.
  Future<int> markSynchronized(String id) async {
    final db = await _db;
    return await db.update(
      'owners',
      {'synchronized': 1, 'updated_at': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Verifica si existe un propietario con el mismo documento.
  Future<bool> existsByDocument(DocumentType type, String number) async {
    final db = await _db;
    final List<Map<String, dynamic>> maps = await db.query(
      'owners',
      where: 'document_type = ? AND document_number = ?',
      whereArgs: [type.name, number],
      limit: 1,
    );
    return maps.isNotEmpty;
  }

  /// Inserta los datos semilla la primera vez (si la tabla está vacía).
  Future<void> seedIfEmpty(List<Owner> seeds) async {
    final db = await _db;
    final count = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM owners'));
    if (count == null || count == 0) {
      final batch = db.batch();
      for (final owner in seeds) {
        // Usar rawInsert con parámetros para el insert de semilla.
        final sql = '''
          INSERT INTO owners (id, full_name, documento_tipo, documento_numero, email, telefono, direccion, activo, sincronizado, creado, actualizado)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''';
        final List<dynamic> args = [
          owner.id,
          owner.fullName,
          owner.documentType.name,
          owner.documentNumber,
          owner.email,
          owner.phone,
          owner.address,
          owner.isActive ? 1 : 0,
          0,
          DateTime.now().millisecondsSinceEpoch,
          DateTime.now().millisecondsSinceEpoch,
        ];
        await db.rawInsert(sql, args);
      }
      await batch.commit(noResult: true);
    }
  }

  /// Convierte un mapa de la BD a objeto [Owner].
  Owner _mapToOwner(Map<String, dynamic> map) => Owner(
    id: map['id'],
    fullName: map['full_name'],
    documentType: DocumentType.values.firstWhere(
      (e) => e.name == map['document_type'],
      orElse: () => DocumentType.citizenshipCard,
    ),
    documentNumber: map['document_number'],
    email: map['email'],
    phone: map['phone'],
    address: map['address'].isNotEmpty ? map['address'] : null,
    isActive: map['is_active'] == 1,
  );
  }
