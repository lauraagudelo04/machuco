/// Configuración común de la base de datos SQLite.
///
/// **Archivo en común del equipo** — cada integrante registra SU tabla aquí
/// mediante la función `registerTables`. Coordinar para evitar conflictos de merge.
///
/// La BD se recrea en cada ejecución de la app (onCreate), funcionando "como JPA":
/// el esquema se deriva de las sentencias CREATE TABLE que cada uno aporta.

import 'package:sqflite/sqflite.dart';

/// Versión del esquema. **Incrementar** cuando se cambie la estructura de tablas
/// y escribir la migración correspondiente en [onUpgrade].
const int databaseVersion = 1;

/// Nombre del archivo de la base de datos.
const String databaseName = 'machuco.db';

/// Callback que se ejecuta al crear la BD por primera vez.
///
/// Cada integrante debe agregar su(s) `CREATE TABLE` aquí dentro de su bloque
/// comentado. No borrar ni tocar bloques de otros compañeros.
Future<void> _onCreate(Database db, int version) async {
  await db.execute('''
    CREATE TABLE owners (
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
  ''');

  // TODO(compañero): Agregar CREATE TABLE de tu entidad aquí
  // Ejemplo:
  // await db.execute('''
  //   CREATE TABLE motels (
  //     id TEXT PRIMARY KEY,
  //     ...
  //   )
  // ''');
}

/// Callback para migraciones de esquema.
///
/// Cuando se incrementa [databaseVersion], implementar aquí las sentencias
/// ALTER TABLE / DROP / CREATE necesarias para migrar de la versión anterior.
Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
  // TODO: Implementar migraciones cuando se suba la versión
  // Ejemplo:
  // if (oldVersion < 2) {
  //   await db.execute('ALTER TABLE owners ADD COLUMN new_field TEXT');
 // }
}

/// Abre (o crea) la base de datos SQLite.
///
/// Usa [path_provider] para ubicar el archivo en el directorio de documentos
/// de la app. Es seguro llamar varias veces: sqflite devuelve la misma
/// instancia si ya está abierta.
Future<Database> openDatabaseInstance() async {
  final documentsPath = await getDatabasesPath();
  final path = '$documentsPath/$databaseName';
  return openDatabase(
    path,
    version: databaseVersion,
    onCreate: _onCreate,
    onUpgrade: _onUpgrade,
  );}
