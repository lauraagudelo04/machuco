/// Data Access Object para la entidad [Owner].
///
/// Encapsula todas las sentencias SQL relacionadas con la tabla `owners`.
/// Sin llaves foráneas ni relaciones: almacenamiento caché/transitorio.

import 'package:sqflite/sqflite.dart';
import 'package:machuco/models/owner_management/owner.dart';
import 'package:machuco/models/owner_management/document_type.dart';
import 'sqlite_database.dart';

class OwnerDao {
  OwnerDao._();

  static final OwnerDao instance = OwnerDao._();

  /// Crea la tabla si no existe (se invoca desde database_config.dart onCreate).
  static const String createTableSql = '''
    CREATE TABLE IF NOT EXISTS owners (
      id TEXT PRIMARY KEY,
      full_name TEXT NOT NULL,
      document_type TEXT NOT NULL,
      document_number TEXT NOT NULL,
      email TEXT NOT NULL,
      phone TEXT NOT NULL,
      address TEXT,
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
    return db.insert('owners', owner.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Actualiza un propietario existente.
  Future<int> update(Owner owner) async {
    final db = await _db;
    return db.update(
      'owners',
      owner.toMap(),
      where: 'id = ?',
      whereArgs: [owner.id],
    );
  }

  /// Elimina un propietario por ID.
  Future<int> delete(String id) async {
    final db = await _db;
    return db.delete('owners', where: 'id = ?', whereArgs: [id]);
  }

  /// Obtiene un propietario por ID.
  Future<Owner?> getById(String id) async {
    final db = await _db;
    final maps = await db.query(
      'owners',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return Owner.fromMap(maps.first);
  }

  /// Obtiene todos los propietarios, ordenados por nombre.
  Future<List<Owner>> getAll({bool onlyActive = false}) async {
    final db = await _db;
    final maps = await db.query(
      'owners',
      where: onlyActive ? 'is_active = 1' : null,
      orderBy: 'full_name ASC',
    );
    return maps.map(Owner.fromMap).toList();
  }

  /// Busca propietarios por nombre, documento o email (contiene, case-insensitive).
  Future<List<Owner>> search(String query) async {
    final db = await _db;
    final like = '%${query.toLowerCase()}%';
    final maps = await db.rawQuery('''
      SELECT * FROM owners
      WHERE LOWER(full_name) LIKE ?
         OR LOWER(document_number) LIKE ?
         OR LOWER(email) LIKE ?
      ORDER BY full_name ASC
    ''', [like, like, like]);
    return maps.map(Owner.fromMap).toList();
  }

  /// Obtiene propietarios que no se han sincronizado con la nube.
  Future<List<Owner>> getUnsynchronized() async {
    final db = await _db;
    final maps = await db.query(
      'owners',
      where: 'synchronized = 0',
      orderBy: 'created_at ASC',
    );
    return maps.map(Owner.fromMap).toList();
  }

  /// Marca un propietario como sincronizado.
  Future<int> markSynchronized(String id) async {
    final db = await _db;
    return db.update(
      'owners',
      {'synchronized': 1, 'updated_at': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Verifica si existe un propietario con el mismo documento.
  Future<bool> existsByDocument(DocumentType type, String number) async {
    final db = await _db;
    final maps = await db.query(
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
        batch.insert('owners', owner.toMap(), conflictAlgorithm: ConflictAlgorithm.ignore);
      }
      await batch.commit(noResult: true);
    }
  }
}