/// Clase de conexión a la base de datos SQLite (Singleton).
///
/// **Archivo en común del equipo** — instancia única que gestiona el ciclo de vida
/// de la BD. No instanciar directamente; usar [SQLiteDatabase.instance].

import 'package:sqflite/sqflite.dart';
import 'database_config.dart';

class SQLiteDatabase {
  SQLiteDatabase._();

  static final SQLiteDatabase instance = SQLiteDatabase._();

  Database? _database;

  /// Obtiene la instancia de la BD, inicializándola si es necesario.
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await openDatabaseInstance();
    return _database!;
  }

  /// Cierra la conexión a la BD.
  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }

  /// Elimina el archivo de la BD (útil para tests o reset manual).
  Future<void> deleteDatabaseFile() async {
    await close();
    final path = await databasePath;
    await deleteDatabase(path);
  }

  /// Ruta al archivo de la BD (expuesta para tests/debug).
  static Future<String> get databasePath async {
    final documentsPath = await getDatabasesPath();
    return '$documentsPath/$databaseName';
  }
}