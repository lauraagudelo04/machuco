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
    database.database = await database.open(
      path,
      _migrations,
      _callback,
    );
    return database;
  }
}

class _$AppDatabase extends AppDatabase {
  _$AppDatabase([StreamController<String>? listener]) {
    changeListener = listener ?? StreamController<String>.broadcast();
  }

  ReservationCategoryDao? _reservationCategoryDaoInstance;

  ReservationDao? _reservationDaoInstance;

  Future<sqflite.Database> open(
    String path,
    List<Migration> migrations, [
    Callback? callback,
  ]) async {
    final databaseOptions = sqflite.OpenDatabaseOptions(
      version: 2,
      onConfigure: (database) async {
        await database.execute('PRAGMA foreign_keys = ON');
        await callback?.onConfigure?.call(database);
      },
      onOpen: (database) async {
        await callback?.onOpen?.call(database);
      },
      onUpgrade: (database, startVersion, endVersion) async {
        await MigrationAdapter.runMigrations(
            database, startVersion, endVersion, migrations);

        await callback?.onUpgrade?.call(database, startVersion, endVersion);
      },
      onCreate: (database, version) async {
        await database.execute(
            'CREATE TABLE IF NOT EXISTS `reservation_categories` (`id` INTEGER NOT NULL, `name` TEXT NOT NULL, PRIMARY KEY (`id`))');
        await database.execute(
            'CREATE TABLE IF NOT EXISTS `reservations` (`id` TEXT NOT NULL, `requestId` TEXT NOT NULL, `motelId` TEXT NOT NULL, `motelName` TEXT NOT NULL, `roomId` TEXT NOT NULL, `roomName` TEXT NOT NULL, `roomNumber` TEXT NOT NULL, `checkIn` INTEGER NOT NULL, `checkOut` INTEGER NOT NULL, `stayMode` TEXT NOT NULL, `guestCount` INTEGER NOT NULL, `roomTotal` INTEGER NOT NULL, `total` INTEGER NOT NULL, `status` TEXT NOT NULL, `createdAt` INTEGER NOT NULL, `guestId` TEXT NOT NULL, `guestName` TEXT NOT NULL, `categoryId` INTEGER, `cancellationReason` TEXT, `invoiceAccessStatus` TEXT NOT NULL, `paymentMethod` TEXT, PRIMARY KEY (`id`))');
        await database.execute(
            'CREATE TABLE IF NOT EXISTS `reservation_line_items` (`rowId` INTEGER PRIMARY KEY AUTOINCREMENT, `reservationId` TEXT NOT NULL, `kind` TEXT NOT NULL, `itemId` TEXT NOT NULL, `name` TEXT NOT NULL, `unitPrice` INTEGER NOT NULL, `quantity` INTEGER NOT NULL, `position` INTEGER NOT NULL, FOREIGN KEY (`reservationId`) REFERENCES `reservations` (`id`) ON UPDATE NO ACTION ON DELETE CASCADE)');
        await database.execute(
            'CREATE INDEX `index_reservations_requestId` ON `reservations` (`requestId`)');
        await database.execute(
            'CREATE INDEX `index_reservations_motelId` ON `reservations` (`motelId`)');
        await database.execute(
            'CREATE INDEX `index_reservation_line_items_reservationId` ON `reservation_line_items` (`reservationId`)');

        await callback?.onCreate?.call(database, version);
      },
    );
    return sqfliteDatabaseFactory.openDatabase(path, options: databaseOptions);
  }

  @override
  ReservationCategoryDao get reservationCategoryDao {
    return _reservationCategoryDaoInstance ??=
        _$ReservationCategoryDao(database, changeListener);
  }

  @override
  ReservationDao get reservationDao {
    return _reservationDaoInstance ??=
        _$ReservationDao(database, changeListener);
  }
}

class _$ReservationCategoryDao extends ReservationCategoryDao {
  _$ReservationCategoryDao(
    this.database,
    this.changeListener,
  )   : _queryAdapter = QueryAdapter(database),
        _reservationCategoryInsertionAdapter = InsertionAdapter(
            database,
            'reservation_categories',
            (ReservationCategory item) =>
                <String, Object?>{'id': item.id, 'name': item.name});

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
            id: row['id'] as int, name: row['name'] as String));
  }

  @override
  Future<ReservationCategory?> findById(int id) async {
    return _queryAdapter.query(
        'SELECT * FROM reservation_categories WHERE id = ?1 LIMIT 1',
        mapper: (Map<String, Object?> row) => ReservationCategory(
            id: row['id'] as int, name: row['name'] as String),
        arguments: [id]);
  }

  @override
  Future<void> insertAll(List<ReservationCategory> categories) async {
    await _reservationCategoryInsertionAdapter.insertList(
        categories, OnConflictStrategy.ignore);
  }

  @override
  Future<void> insertCategory(ReservationCategory category) async {
    await _reservationCategoryInsertionAdapter.insert(
        category, OnConflictStrategy.ignore);
  }
}

class _$ReservationDao extends ReservationDao {
  _$ReservationDao(
    this.database,
    this.changeListener,
  )   : _queryAdapter = QueryAdapter(database),
        _reservationEntityInsertionAdapter = InsertionAdapter(
            database,
            'reservations',
            (ReservationEntity item) => <String, Object?>{
                  'id': item.id,
                  'requestId': item.requestId,
                  'motelId': item.motelId,
                  'motelName': item.motelName,
                  'roomId': item.roomId,
                  'roomName': item.roomName,
                  'roomNumber': item.roomNumber,
                  'checkIn': item.checkIn,
                  'checkOut': item.checkOut,
                  'stayMode': item.stayMode,
                  'guestCount': item.guestCount,
                  'roomTotal': item.roomTotal,
                  'total': item.total,
                  'status': item.status,
                  'createdAt': item.createdAt,
                  'guestId': item.guestId,
                  'guestName': item.guestName,
                  'categoryId': item.categoryId,
                  'cancellationReason': item.cancellationReason,
                  'invoiceAccessStatus': item.invoiceAccessStatus,
                  'paymentMethod': item.paymentMethod
                }),
        _reservationLineItemEntityInsertionAdapter = InsertionAdapter(
            database,
            'reservation_line_items',
            (ReservationLineItemEntity item) => <String, Object?>{
                  'rowId': item.rowId,
                  'reservationId': item.reservationId,
                  'kind': item.kind,
                  'itemId': item.itemId,
                  'name': item.name,
                  'unitPrice': item.unitPrice,
                  'quantity': item.quantity,
                  'position': item.position
                }),
        _reservationEntityUpdateAdapter = UpdateAdapter(
            database,
            'reservations',
            ['id'],
            (ReservationEntity item) => <String, Object?>{
                  'id': item.id,
                  'requestId': item.requestId,
                  'motelId': item.motelId,
                  'motelName': item.motelName,
                  'roomId': item.roomId,
                  'roomName': item.roomName,
                  'roomNumber': item.roomNumber,
                  'checkIn': item.checkIn,
                  'checkOut': item.checkOut,
                  'stayMode': item.stayMode,
                  'guestCount': item.guestCount,
                  'roomTotal': item.roomTotal,
                  'total': item.total,
                  'status': item.status,
                  'createdAt': item.createdAt,
                  'guestId': item.guestId,
                  'guestName': item.guestName,
                  'categoryId': item.categoryId,
                  'cancellationReason': item.cancellationReason,
                  'invoiceAccessStatus': item.invoiceAccessStatus,
                  'paymentMethod': item.paymentMethod
                });

  final sqflite.DatabaseExecutor database;

  final StreamController<String> changeListener;

  final QueryAdapter _queryAdapter;

  final InsertionAdapter<ReservationEntity> _reservationEntityInsertionAdapter;

  final InsertionAdapter<ReservationLineItemEntity>
      _reservationLineItemEntityInsertionAdapter;

  final UpdateAdapter<ReservationEntity> _reservationEntityUpdateAdapter;

  @override
  Future<List<ReservationEntity>> findAllReservations() async {
    return _queryAdapter.queryList('SELECT * FROM reservations',
        mapper: (Map<String, Object?> row) => ReservationEntity(
            id: row['id'] as String,
            requestId: row['requestId'] as String,
            motelId: row['motelId'] as String,
            motelName: row['motelName'] as String,
            roomId: row['roomId'] as String,
            roomName: row['roomName'] as String,
            roomNumber: row['roomNumber'] as String,
            checkIn: row['checkIn'] as int,
            checkOut: row['checkOut'] as int,
            stayMode: row['stayMode'] as String,
            guestCount: row['guestCount'] as int,
            roomTotal: row['roomTotal'] as int,
            total: row['total'] as int,
            status: row['status'] as String,
            createdAt: row['createdAt'] as int,
            guestId: row['guestId'] as String,
            guestName: row['guestName'] as String,
            categoryId: row['categoryId'] as int?,
            cancellationReason: row['cancellationReason'] as String?,
            invoiceAccessStatus: row['invoiceAccessStatus'] as String,
            paymentMethod: row['paymentMethod'] as String?));
  }

  @override
  Future<ReservationEntity?> findReservationById(String id) async {
    return _queryAdapter.query(
        'SELECT * FROM reservations WHERE id = ?1 LIMIT 1',
        mapper: (Map<String, Object?> row) => ReservationEntity(
            id: row['id'] as String,
            requestId: row['requestId'] as String,
            motelId: row['motelId'] as String,
            motelName: row['motelName'] as String,
            roomId: row['roomId'] as String,
            roomName: row['roomName'] as String,
            roomNumber: row['roomNumber'] as String,
            checkIn: row['checkIn'] as int,
            checkOut: row['checkOut'] as int,
            stayMode: row['stayMode'] as String,
            guestCount: row['guestCount'] as int,
            roomTotal: row['roomTotal'] as int,
            total: row['total'] as int,
            status: row['status'] as String,
            createdAt: row['createdAt'] as int,
            guestId: row['guestId'] as String,
            guestName: row['guestName'] as String,
            categoryId: row['categoryId'] as int?,
            cancellationReason: row['cancellationReason'] as String?,
            invoiceAccessStatus: row['invoiceAccessStatus'] as String,
            paymentMethod: row['paymentMethod'] as String?),
        arguments: [id]);
  }

  @override
  Future<ReservationEntity?> findReservationByRequestId(
      String requestId) async {
    return _queryAdapter.query(
        'SELECT * FROM reservations WHERE requestId = ?1 LIMIT 1',
        mapper: (Map<String, Object?> row) => ReservationEntity(
            id: row['id'] as String,
            requestId: row['requestId'] as String,
            motelId: row['motelId'] as String,
            motelName: row['motelName'] as String,
            roomId: row['roomId'] as String,
            roomName: row['roomName'] as String,
            roomNumber: row['roomNumber'] as String,
            checkIn: row['checkIn'] as int,
            checkOut: row['checkOut'] as int,
            stayMode: row['stayMode'] as String,
            guestCount: row['guestCount'] as int,
            roomTotal: row['roomTotal'] as int,
            total: row['total'] as int,
            status: row['status'] as String,
            createdAt: row['createdAt'] as int,
            guestId: row['guestId'] as String,
            guestName: row['guestName'] as String,
            categoryId: row['categoryId'] as int?,
            cancellationReason: row['cancellationReason'] as String?,
            invoiceAccessStatus: row['invoiceAccessStatus'] as String,
            paymentMethod: row['paymentMethod'] as String?),
        arguments: [requestId]);
  }

  @override
  Future<int?> countReservations() async {
    return _queryAdapter.query('SELECT COUNT(*) FROM reservations',
        mapper: (Map<String, Object?> row) => row.values.first as int);
  }

  @override
  Future<List<ReservationLineItemEntity>> findAllLineItems() async {
    return _queryAdapter.queryList(
        'SELECT * FROM reservation_line_items ORDER BY reservationId, position',
        mapper: (Map<String, Object?> row) => ReservationLineItemEntity(
            rowId: row['rowId'] as int?,
            reservationId: row['reservationId'] as String,
            kind: row['kind'] as String,
            itemId: row['itemId'] as String,
            name: row['name'] as String,
            unitPrice: row['unitPrice'] as int,
            quantity: row['quantity'] as int,
            position: row['position'] as int));
  }

  @override
  Future<List<ReservationLineItemEntity>> findLineItems(
      String reservationId) async {
    return _queryAdapter.queryList(
        'SELECT * FROM reservation_line_items WHERE reservationId = ?1 ORDER BY position',
        mapper: (Map<String, Object?> row) => ReservationLineItemEntity(rowId: row['rowId'] as int?, reservationId: row['reservationId'] as String, kind: row['kind'] as String, itemId: row['itemId'] as String, name: row['name'] as String, unitPrice: row['unitPrice'] as int, quantity: row['quantity'] as int, position: row['position'] as int),
        arguments: [reservationId]);
  }

  @override
  Future<void> deleteLineItems(String id) async {
    await _queryAdapter.queryNoReturn(
        'DELETE FROM reservation_line_items WHERE reservationId = ?1',
        arguments: [id]);
  }

  @override
  Future<void> insertReservationRow(ReservationEntity reservation) async {
    await _reservationEntityInsertionAdapter.insert(
        reservation, OnConflictStrategy.replace);
  }

  @override
  Future<void> insertLineItems(List<ReservationLineItemEntity> items) async {
    await _reservationLineItemEntityInsertionAdapter.insertList(
        items, OnConflictStrategy.abort);
  }

  @override
  Future<void> updateReservationRow(ReservationEntity reservation) async {
    await _reservationEntityUpdateAdapter.update(
        reservation, OnConflictStrategy.abort);
  }

  @override
  Future<void> insertReservation(
    ReservationEntity reservation,
    List<ReservationLineItemEntity> items,
  ) async {
    if (database is sqflite.Transaction) {
      await super.insertReservation(reservation, items);
    } else {
      await (database as sqflite.Database)
          .transaction<void>((transaction) async {
        final transactionDatabase = _$AppDatabase(changeListener)
          ..database = transaction;
        await transactionDatabase.reservationDao
            .insertReservation(reservation, items);
      });
    }
  }

  @override
  Future<void> replaceReservation(
    ReservationEntity reservation,
    List<ReservationLineItemEntity> items,
  ) async {
    if (database is sqflite.Transaction) {
      await super.replaceReservation(reservation, items);
    } else {
      await (database as sqflite.Database)
          .transaction<void>((transaction) async {
        final transactionDatabase = _$AppDatabase(changeListener)
          ..database = transaction;
        await transactionDatabase.reservationDao
            .replaceReservation(reservation, items);
      });
    }
  }
}
