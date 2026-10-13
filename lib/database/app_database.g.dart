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

  SubscriptionDao? _subscriptionDaoInstance;

  Future<sqflite.Database> open(
    String path,
    List<Migration> migrations, [
    Callback? callback,
  ]) async {
    final databaseOptions = sqflite.OpenDatabaseOptions(
      version: 4,
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
            'CREATE TABLE IF NOT EXISTS `subscriptions` (`id` INTEGER PRIMARY KEY AUTOINCREMENT, `userEmail` TEXT, `planId` INTEGER, `planName` TEXT NOT NULL, `motelName` TEXT NOT NULL, `amount` INTEGER NOT NULL, `billingPeriod` TEXT NOT NULL, `nextBillingDate` INTEGER NOT NULL, `status` TEXT NOT NULL, `features` TEXT NOT NULL)');
        await database.execute(
            'CREATE TABLE IF NOT EXISTS `subscription_payments` (`id` INTEGER PRIMARY KEY AUTOINCREMENT, `subscriptionId` INTEGER NOT NULL, `date` INTEGER NOT NULL, `amount` INTEGER NOT NULL, `paymentMethod` TEXT NOT NULL, `reference` TEXT NOT NULL, `status` TEXT NOT NULL, FOREIGN KEY (`subscriptionId`) REFERENCES `subscriptions` (`id`) ON UPDATE NO ACTION ON DELETE NO ACTION)');
        await database.execute(
            'CREATE INDEX `index_subscription_payments_subscriptionId` ON `subscription_payments` (`subscriptionId`)');

        await callback?.onCreate?.call(database, version);
      },
    );
    return sqfliteDatabaseFactory.openDatabase(path, options: databaseOptions);
  }

  @override
  SubscriptionDao get subscriptionDao {
    return _subscriptionDaoInstance ??=
        _$SubscriptionDao(database, changeListener);
  }
}

class _$SubscriptionDao extends SubscriptionDao {
  _$SubscriptionDao(
    this.database,
    this.changeListener,
  )   : _queryAdapter = QueryAdapter(database),
        _subscriptionDetailsInsertionAdapter = InsertionAdapter(
            database,
            'subscriptions',
            (SubscriptionDetails item) => <String, Object?>{
                  'id': item.id,
                  'userEmail': item.userEmail,
                  'planId': item.planId,
                  'planName': item.planName,
                  'motelName': item.motelName,
                  'amount': item.amount,
                  'billingPeriod': item.billingPeriod,
                  'nextBillingDate':
                      _subscriptionDateConverter.encode(item.nextBillingDate),
                  'status': _subscriptionStatusConverter.encode(item.status),
                  'features':
                      _subscriptionFeaturesConverter.encode(item.features)
                }),
        _subscriptionPaymentInsertionAdapter = InsertionAdapter(
            database,
            'subscription_payments',
            (SubscriptionPayment item) => <String, Object?>{
                  'id': item.id,
                  'subscriptionId': item.subscriptionId,
                  'date': _subscriptionDateConverter.encode(item.date),
                  'amount': item.amount,
                  'paymentMethod': item.paymentMethod,
                  'reference': item.reference,
                  'status': _subscriptionStatusConverter.encode(item.status)
                }),
        _subscriptionDetailsUpdateAdapter = UpdateAdapter(
            database,
            'subscriptions',
            ['id'],
            (SubscriptionDetails item) => <String, Object?>{
                  'id': item.id,
                  'userEmail': item.userEmail,
                  'planId': item.planId,
                  'planName': item.planName,
                  'motelName': item.motelName,
                  'amount': item.amount,
                  'billingPeriod': item.billingPeriod,
                  'nextBillingDate':
                      _subscriptionDateConverter.encode(item.nextBillingDate),
                  'status': _subscriptionStatusConverter.encode(item.status),
                  'features':
                      _subscriptionFeaturesConverter.encode(item.features)
                });

  final sqflite.DatabaseExecutor database;

  final StreamController<String> changeListener;

  final QueryAdapter _queryAdapter;

  final InsertionAdapter<SubscriptionDetails>
      _subscriptionDetailsInsertionAdapter;

  final InsertionAdapter<SubscriptionPayment>
      _subscriptionPaymentInsertionAdapter;

  final UpdateAdapter<SubscriptionDetails> _subscriptionDetailsUpdateAdapter;

  @override
  Future<SubscriptionDetails?> findById(int id) async {
    return _queryAdapter.query(
        'SELECT * FROM subscriptions WHERE id = ?1 LIMIT 1',
        mapper: (Map<String, Object?> row) => SubscriptionDetails(
            id: row['id'] as int?,
            userEmail: row['userEmail'] as String?,
            planId: row['planId'] as int?,
            planName: row['planName'] as String,
            motelName: row['motelName'] as String,
            amount: row['amount'] as int,
            billingPeriod: row['billingPeriod'] as String,
            nextBillingDate: _subscriptionDateConverter
                .decode(row['nextBillingDate'] as int),
            status:
                _subscriptionStatusConverter.decode(row['status'] as String),
            features: _subscriptionFeaturesConverter
                .decode(row['features'] as String)),
        arguments: [id]);
  }

  @override
  Future<SubscriptionDetails?> findFirst() async {
    return _queryAdapter.query(
        'SELECT * FROM subscriptions ORDER BY id LIMIT 1',
        mapper: (Map<String, Object?> row) => SubscriptionDetails(
            id: row['id'] as int?,
            userEmail: row['userEmail'] as String?,
            planId: row['planId'] as int?,
            planName: row['planName'] as String,
            motelName: row['motelName'] as String,
            amount: row['amount'] as int,
            billingPeriod: row['billingPeriod'] as String,
            nextBillingDate: _subscriptionDateConverter
                .decode(row['nextBillingDate'] as int),
            status:
                _subscriptionStatusConverter.decode(row['status'] as String),
            features: _subscriptionFeaturesConverter
                .decode(row['features'] as String)));
  }

  @override
  Future<SubscriptionDetails?> findByEmail(String email) async {
    return _queryAdapter.query(
        'SELECT * FROM subscriptions WHERE userEmail = ?1 ORDER BY id LIMIT 1',
        mapper: (Map<String, Object?> row) => SubscriptionDetails(
            id: row['id'] as int?,
            userEmail: row['userEmail'] as String?,
            planId: row['planId'] as int?,
            planName: row['planName'] as String,
            motelName: row['motelName'] as String,
            amount: row['amount'] as int,
            billingPeriod: row['billingPeriod'] as String,
            nextBillingDate: _subscriptionDateConverter
                .decode(row['nextBillingDate'] as int),
            status:
                _subscriptionStatusConverter.decode(row['status'] as String),
            features: _subscriptionFeaturesConverter
                .decode(row['features'] as String)),
        arguments: [email]);
  }

  @override
  Future<List<SubscriptionPayment>> findPayments(int subscriptionId) async {
    return _queryAdapter.queryList(
        'SELECT * FROM subscription_payments WHERE subscriptionId = ?1 ORDER BY date DESC, id DESC',
        mapper: (Map<String, Object?> row) => SubscriptionPayment(id: row['id'] as int?, subscriptionId: row['subscriptionId'] as int, date: _subscriptionDateConverter.decode(row['date'] as int), amount: row['amount'] as int, paymentMethod: row['paymentMethod'] as String, reference: row['reference'] as String, status: _subscriptionStatusConverter.decode(row['status'] as String)),
        arguments: [subscriptionId]);
  }

  @override
  Future<int> insertSubscription(SubscriptionDetails subscription) {
    return _subscriptionDetailsInsertionAdapter.insertAndReturnId(
        subscription, OnConflictStrategy.abort);
  }

  @override
  Future<int> insertPayment(SubscriptionPayment payment) {
    return _subscriptionPaymentInsertionAdapter.insertAndReturnId(
        payment, OnConflictStrategy.abort);
  }

  @override
  Future<int> updateSubscription(SubscriptionDetails subscription) {
    return _subscriptionDetailsUpdateAdapter.updateAndReturnChangedRows(
        subscription, OnConflictStrategy.abort);
  }
}

// ignore_for_file: unused_element
final _subscriptionDateConverter = SubscriptionDateConverter();
final _subscriptionStatusConverter = SubscriptionStatusConverter();
final _subscriptionFeaturesConverter = SubscriptionFeaturesConverter();
