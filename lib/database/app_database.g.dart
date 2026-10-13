// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// **************************************************************************
// FloorGenerator
// **************************************************************************

abstract class $AppDatabaseBuilderContract {
  /// Adds migrations to the builder.
  $AppDatabaseBuilderContract addMigrations(List<Migration> migrations);

  /// Adds a database [Callback] to the builder.
  $AppDatabaseBuilderContract addCallback(Callback callback);

  /// Creates the database and initializes it.
  Future<AppDatabase> build();
}

// ignore: avoid_classes_with_only_static_members
class $FloorAppDatabase {
  /// Creates a database builder for a persistent database.
  /// Once a database is built, you should keep a reference to it and re-use it.
  static $AppDatabaseBuilderContract databaseBuilder(String name) =>
      _$AppDatabaseBuilder(name);

  /// Creates a database builder for an in memory database.
  /// Information stored in an in memory database disappears when the process is killed.
  /// Once a database is built, you should keep a reference to it and re-use it.
  static $AppDatabaseBuilderContract inMemoryDatabaseBuilder() =>
      _$AppDatabaseBuilder(null);
}

class _$AppDatabaseBuilder implements $AppDatabaseBuilderContract {
  _$AppDatabaseBuilder(this.name);

  final String? name;

  final List<Migration> _migrations = [];

  Callback? _callback;

  @override
  $AppDatabaseBuilderContract addMigrations(List<Migration> migrations) {
    _migrations.addAll(migrations);
    return this;
  }

  @override
  $AppDatabaseBuilderContract addCallback(Callback callback) {
    _callback = callback;
    return this;
  }

  @override
  Future<AppDatabase> build() async {
    final path = name != null
        ? await sqfliteDatabaseFactory.getDatabasePath(name!)
        : ':memory:';
    final database = _$AppDatabase();
    database.database = await database.open(path, _migrations, _callback);
    return database;
  }
}

class _$AppDatabase extends AppDatabase {
  _$AppDatabase([StreamController<String>? listener]) {
    changeListener = listener ?? StreamController<String>.broadcast();
  }

  ReservationCategoryDao? _reservationCategoryDaoInstance;

  Future<sqflite.Database> open(
    String path,
    List<Migration> migrations, [
    Callback? callback,
  ]) async {
    final databaseOptions = sqflite.OpenDatabaseOptions(
      version: 1,
      onConfigure: (database) async {
        await database.execute('PRAGMA foreign_keys = ON');
        await callback?.onConfigure?.call(database);
      },
      onOpen: (database) async {
        await callback?.onOpen?.call(database);
      },
      onUpgrade: (database, startVersion, endVersion) async {
        await MigrationAdapter.runMigrations(
          database,
          startVersion,
          endVersion,
          migrations,
        );

        await callback?.onUpgrade?.call(database, startVersion, endVersion);
      },
      onCreate: (database, version) async {
        await database.execute(
          'CREATE TABLE IF NOT EXISTS `reservation_categories` (`id` INTEGER NOT NULL, `name` TEXT NOT NULL, PRIMARY KEY (`id`))',
        );

        await callback?.onCreate?.call(database, version);
      },
    );
    return sqfliteDatabaseFactory.openDatabase(path, options: databaseOptions);
  }

  @override
  ReservationCategoryDao get reservationCategoryDao {
    return _reservationCategoryDaoInstance ??= _$ReservationCategoryDao(
      database,
      changeListener,
    );
  }
}

class _$ReservationCategoryDao extends ReservationCategoryDao {
  _$ReservationCategoryDao(this.database, this.changeListener)
    : _queryAdapter = QueryAdapter(database),
      _reservationCategoryInsertionAdapter = InsertionAdapter(
        database,
        'reservation_categories',
        (ReservationCategory item) => <String, Object?>{
          'id': item.id,
          'name': item.name,
        },
      );

  final sqflite.DatabaseExecutor database;

  final StreamController<String> changeListener;

  final QueryAdapter _queryAdapter;

  final InsertionAdapter<ReservationCategory>
  _reservationCategoryInsertionAdapter;

  @override
  Future<List<ReservationCategory>> findAll() async {
    return _queryAdapter.queryList(
      'SELECT * FROM reservation_categories ORDER BY name ASC',
      mapper: (Map<String, Object?> row) => ReservationCategory(
        id: row['id'] as int,
        name: row['name'] as String,
      ),
    );
  }

  @override
  Future<ReservationCategory?> findById(int id) async {
    return _queryAdapter.query(
      'SELECT * FROM reservation_categories WHERE id = ?1 LIMIT 1',
      mapper: (Map<String, Object?> row) => ReservationCategory(
        id: row['id'] as int,
        name: row['name'] as String,
      ),
      arguments: [id],
    );
  }

  @override
  Future<void> insertAll(List<ReservationCategory> categories) async {
    await _reservationCategoryInsertionAdapter.insertList(
      categories,
      OnConflictStrategy.ignore,
    );
  }

  @override
  Future<void> insertCategory(ReservationCategory category) async {
    await _reservationCategoryInsertionAdapter.insert(
      category,
      OnConflictStrategy.ignore,
    );
  }
}
