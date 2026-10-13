import 'package:flutter/foundation.dart';
import 'package:machuco/repositories/room/room_dao.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

/// Configuración central de la base SQLite local.
class AppDatabase {
  AppDatabase({DatabaseFactory? factory, this.databasePath})
    : _databaseFactory = factory ?? _platformDatabaseFactory();

  static const databaseName = 'machuco.db';
  static const databaseVersion = 1;

  final DatabaseFactory _databaseFactory;
  final String? databasePath;
  Future<Database>? _database;
  RoomDao? _roomDao;

  Future<Database> get database => _database ??= _openDatabase();

  RoomDao get roomDao => _roomDao ??= RoomDao(() => database);

  Future<Database> _openDatabase() async {
    final path =
        databasePath ??
        (kIsWeb
            ? databaseName
            : '${await _databaseFactory.getDatabasesPath()}/$databaseName');
    return _databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: databaseVersion,
        onConfigure: (database) async {
          await database.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: (database, _) => createSchema(database),
      ),
    );
  }

  static DatabaseFactory _platformDatabaseFactory() =>
      kIsWeb ? databaseFactoryFfiWeb : databaseFactory;

  static Future<void> createSchema(Database database) async {
    await database.execute('''
      CREATE TABLE room_types (
        id TEXT PRIMARY KEY,
        motel_id TEXT NOT NULL,
        name TEXT NOT NULL
      )
    ''');
    await database.execute('''
      CREATE UNIQUE INDEX room_types_motel_name
      ON room_types(motel_id, name COLLATE NOCASE)
    ''');
    await database.execute('''
      CREATE TABLE rooms (
        id TEXT PRIMARY KEY,
        motel_id TEXT NOT NULL,
        name TEXT NOT NULL,
        description TEXT NOT NULL,
        type_id TEXT NOT NULL,
        price_per_hour INTEGER NOT NULL,
        room_number TEXT NOT NULL,
        capacity INTEGER NOT NULL,
        image_urls_json TEXT NOT NULL,
        is_active INTEGER NOT NULL CHECK (is_active IN (0, 1)),
        included_services_json TEXT NOT NULL,
        FOREIGN KEY (type_id) REFERENCES room_types(id)
          ON UPDATE CASCADE ON DELETE RESTRICT
      )
    ''');
    await database.execute('''
      CREATE UNIQUE INDEX rooms_motel_number
      ON rooms(motel_id, room_number COLLATE NOCASE)
    ''');
    await database.execute('''
      CREATE TABLE room_included_services (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL UNIQUE
      )
    ''');
  }

  Future<void> close() async {
    final currentDatabase = _database;
    if (currentDatabase != null) {
      await (await currentDatabase).close();
      _database = null;
      _roomDao = null;
    }
  }
}
