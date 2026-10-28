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

  NotificationDao? _notificationDaoInstance;

  PaymentDao? _paymentDaoInstance;

  ClientDao? _clientDaoInstance;

  PhoneCountryCodeDao? _phoneCountryCodeDaoInstance;

  Future<sqflite.Database> open(
    String path,
    List<Migration> migrations, [
    Callback? callback,
  ]) async {
    final databaseOptions = sqflite.OpenDatabaseOptions(
      version: 10,
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
            'CREATE TABLE IF NOT EXISTS `notifications` (`id` INTEGER PRIMARY KEY AUTOINCREMENT, `typeId` INTEGER NOT NULL, `title` TEXT NOT NULL, `message` TEXT NOT NULL, `sentAt` INTEGER NOT NULL, `target` TEXT NOT NULL, `recipientUser` TEXT)');
        await database.execute(
            'CREATE TABLE IF NOT EXISTS `notification_reads` (`id` INTEGER PRIMARY KEY AUTOINCREMENT, `notificationId` INTEGER NOT NULL, `userId` TEXT NOT NULL, `readAt` INTEGER NOT NULL, FOREIGN KEY (`notificationId`) REFERENCES `notifications` (`id`) ON UPDATE NO ACTION ON DELETE NO ACTION)');
        await database.execute(
            'CREATE TABLE IF NOT EXISTS `payment_method_catalog` (`id` INTEGER NOT NULL, `name` TEXT NOT NULL, PRIMARY KEY (`id`))');
        await database.execute(
            'CREATE TABLE IF NOT EXISTS `payments` (`id` TEXT NOT NULL, `bookingId` TEXT NOT NULL, `bookingReference` TEXT NOT NULL, `clientId` TEXT NOT NULL, `client` TEXT NOT NULL, `motelId` TEXT NOT NULL, `motel` TEXT NOT NULL, `roomId` TEXT NOT NULL, `room` TEXT NOT NULL, `reservationDate` INTEGER NOT NULL, `amount` INTEGER NOT NULL, `status` TEXT NOT NULL, `method` TEXT, `paymentMethodId` INTEGER, `paidAt` INTEGER, `receiptNumber` TEXT, FOREIGN KEY (`paymentMethodId`) REFERENCES `payment_method_catalog` (`id`) ON UPDATE NO ACTION ON DELETE NO ACTION, PRIMARY KEY (`id`))');
        await database.execute(
            'CREATE TABLE IF NOT EXISTS `clients` (`id` INTEGER PRIMARY KEY AUTOINCREMENT, `name` TEXT NOT NULL, `phone` TEXT NOT NULL, `email` TEXT NOT NULL, `country_code` TEXT NOT NULL, `password` TEXT NOT NULL)');
        await database.execute(
            'CREATE TABLE IF NOT EXISTS `phone_country_codes` (`id` INTEGER NOT NULL, `country_code` TEXT NOT NULL, `country_name` TEXT NOT NULL, `calling_code` TEXT NOT NULL, `active` INTEGER NOT NULL, PRIMARY KEY (`id`))');
        await database.execute(
            'CREATE INDEX `index_subscription_payments_subscriptionId` ON `subscription_payments` (`subscriptionId`)');
        await database.execute(
            'CREATE UNIQUE INDEX `index_notification_reads_notificationId_userId` ON `notification_reads` (`notificationId`, `userId`)');
        await database.execute(
            'CREATE INDEX `index_payments_clientId` ON `payments` (`clientId`)');
        await database.execute(
            'CREATE INDEX `index_payments_motelId` ON `payments` (`motelId`)');
        await database.execute(
            'CREATE INDEX `index_payments_paymentMethodId` ON `payments` (`paymentMethodId`)');

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

  @override
  NotificationDao get notificationDao {
    return _notificationDaoInstance ??=
        _$NotificationDao(database, changeListener);
  }

  @override
  PaymentDao get paymentDao {
    return _paymentDaoInstance ??= _$PaymentDao(database, changeListener);
  }

  @override
  ClientDao get clientDao {
    return _clientDaoInstance ??= _$ClientDao(database, changeListener);
  }

  @override
  PhoneCountryCodeDao get phoneCountryCodeDao {
    return _phoneCountryCodeDaoInstance ??=
        _$PhoneCountryCodeDao(database, changeListener);
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

class _$NotificationDao extends NotificationDao {
  _$NotificationDao(
    this.database,
    this.changeListener,
  )   : _queryAdapter = QueryAdapter(database),
        _notificationEntryInsertionAdapter = InsertionAdapter(
            database,
            'notifications',
            (NotificationEntry item) => <String, Object?>{
                  'id': item.id,
                  'typeId': item.typeId,
                  'title': item.title,
                  'message': item.message,
                  'sentAt': _subscriptionDateConverter.encode(item.sentAt),
                  'target': item.target,
                  'recipientUser': item.recipientUser
                }),
        _notificationReadInsertionAdapter = InsertionAdapter(
            database,
            'notification_reads',
            (NotificationRead item) => <String, Object?>{
                  'id': item.id,
                  'notificationId': item.notificationId,
                  'userId': item.userId,
                  'readAt': _subscriptionDateConverter.encode(item.readAt)
                });

  final sqflite.DatabaseExecutor database;

  final StreamController<String> changeListener;

  final QueryAdapter _queryAdapter;

  final InsertionAdapter<NotificationEntry> _notificationEntryInsertionAdapter;

  final InsertionAdapter<NotificationRead> _notificationReadInsertionAdapter;

  @override
  Future<List<NotificationEntry>> findAll() async {
    return _queryAdapter.queryList(
        'SELECT * FROM notifications ORDER BY sentAt DESC, id DESC',
        mapper: (Map<String, Object?> row) => NotificationEntry(
            id: row['id'] as int?,
            typeId: row['typeId'] as int,
            title: row['title'] as String,
            message: row['message'] as String,
            sentAt: _subscriptionDateConverter.decode(row['sentAt'] as int),
            target: row['target'] as String,
            recipientUser: row['recipientUser'] as String?));
  }

  @override
  Future<List<NotificationEntry>> findForRecipient(String recipientUser) async {
    return _queryAdapter.queryList(
        'SELECT * FROM notifications WHERE target = \'all\' OR lower(recipientUser) = lower(?1) ORDER BY sentAt DESC, id DESC',
        mapper: (Map<String, Object?> row) => NotificationEntry(id: row['id'] as int?, typeId: row['typeId'] as int, title: row['title'] as String, message: row['message'] as String, sentAt: _subscriptionDateConverter.decode(row['sentAt'] as int), target: row['target'] as String, recipientUser: row['recipientUser'] as String?),
        arguments: [recipientUser]);
  }

  @override
  Future<List<int>> findReadNotificationIds(String userId) async {
    return _queryAdapter.queryList(
        'SELECT notificationId FROM notification_reads WHERE userId = ?1',
        mapper: (Map<String, Object?> row) => row.values.first as int,
        arguments: [userId]);
  }

  @override
  Future<NotificationRead?> findRead(
    int notificationId,
    String userId,
  ) async {
    return _queryAdapter.query(
        'SELECT * FROM notification_reads WHERE notificationId = ?1 AND userId = ?2 LIMIT 1',
        mapper: (Map<String, Object?> row) => NotificationRead(id: row['id'] as int?, notificationId: row['notificationId'] as int, userId: row['userId'] as String, readAt: _subscriptionDateConverter.decode(row['readAt'] as int)),
        arguments: [notificationId, userId]);
  }

  @override
  Future<int> insertNotification(NotificationEntry notification) {
    return _notificationEntryInsertionAdapter.insertAndReturnId(
        notification, OnConflictStrategy.abort);
  }

  @override
  Future<int> insertRead(NotificationRead notificationRead) {
    return _notificationReadInsertionAdapter.insertAndReturnId(
        notificationRead, OnConflictStrategy.abort);
  }
}

class _$PaymentDao extends PaymentDao {
  _$PaymentDao(
    this.database,
    this.changeListener,
  )   : _queryAdapter = QueryAdapter(database),
        _paymentRecordInsertionAdapter = InsertionAdapter(
            database,
            'payments',
            (PaymentRecord item) => <String, Object?>{
                  'id': item.id,
                  'bookingId': item.bookingId,
                  'bookingReference': item.bookingReference,
                  'clientId': item.clientId,
                  'client': item.client,
                  'motelId': item.motelId,
                  'motel': item.motel,
                  'roomId': item.roomId,
                  'room': item.room,
                  'reservationDate':
                      _subscriptionDateConverter.encode(item.reservationDate),
                  'amount': item.amount,
                  'status': _paymentStatusConverter.encode(item.status),
                  'method': _paymentMethodConverter.encode(item.method),
                  'paymentMethodId': item.paymentMethodId,
                  'paidAt': _paymentOptionalDateConverter.encode(item.paidAt),
                  'receiptNumber': item.receiptNumber
                }),
        _paymentCatalogEntryInsertionAdapter = InsertionAdapter(
            database,
            'payment_method_catalog',
            (PaymentCatalogEntry item) =>
                <String, Object?>{'id': item.id, 'name': item.name}),
        _paymentCatalogEntryUpdateAdapter = UpdateAdapter(
            database,
            'payment_method_catalog',
            ['id'],
            (PaymentCatalogEntry item) =>
                <String, Object?>{'id': item.id, 'name': item.name});

  final sqflite.DatabaseExecutor database;

  final StreamController<String> changeListener;

  final QueryAdapter _queryAdapter;

  final InsertionAdapter<PaymentRecord> _paymentRecordInsertionAdapter;

  final InsertionAdapter<PaymentCatalogEntry>
      _paymentCatalogEntryInsertionAdapter;

  final UpdateAdapter<PaymentCatalogEntry> _paymentCatalogEntryUpdateAdapter;

  @override
  Future<List<PaymentRecord>> findAll() async {
    return _queryAdapter.queryList(
        'SELECT * FROM payments ORDER BY reservationDate DESC, id DESC',
        mapper: (Map<String, Object?> row) => PaymentRecord(
            id: row['id'] as String,
            bookingId: row['bookingId'] as String,
            bookingReference: row['bookingReference'] as String,
            clientId: row['clientId'] as String,
            client: row['client'] as String,
            motelId: row['motelId'] as String,
            motel: row['motel'] as String,
            roomId: row['roomId'] as String,
            room: row['room'] as String,
            reservationDate: _subscriptionDateConverter
                .decode(row['reservationDate'] as int),
            amount: row['amount'] as int,
            status: _paymentStatusConverter.decode(row['status'] as String),
            method: _paymentMethodConverter.decode(row['method'] as String?),
            paymentMethodId: row['paymentMethodId'] as int?,
            paidAt: _paymentOptionalDateConverter.decode(row['paidAt'] as int?),
            receiptNumber: row['receiptNumber'] as String?));
  }

  @override
  Future<PaymentRecord?> findById(String id) async {
    return _queryAdapter.query('SELECT * FROM payments WHERE id = ?1 LIMIT 1',
        mapper: (Map<String, Object?> row) => PaymentRecord(
            id: row['id'] as String,
            bookingId: row['bookingId'] as String,
            bookingReference: row['bookingReference'] as String,
            clientId: row['clientId'] as String,
            client: row['client'] as String,
            motelId: row['motelId'] as String,
            motel: row['motel'] as String,
            roomId: row['roomId'] as String,
            room: row['room'] as String,
            reservationDate: _subscriptionDateConverter
                .decode(row['reservationDate'] as int),
            amount: row['amount'] as int,
            status: _paymentStatusConverter.decode(row['status'] as String),
            method: _paymentMethodConverter.decode(row['method'] as String?),
            paymentMethodId: row['paymentMethodId'] as int?,
            paidAt: _paymentOptionalDateConverter.decode(row['paidAt'] as int?),
            receiptNumber: row['receiptNumber'] as String?),
        arguments: [id]);
  }

  @override
  Future<List<PaymentRecord>> findByClient(String clientId) async {
    return _queryAdapter.queryList(
        'SELECT * FROM payments WHERE clientId = ?1 ORDER BY reservationDate DESC, id DESC',
        mapper: (Map<String, Object?> row) => PaymentRecord(id: row['id'] as String, bookingId: row['bookingId'] as String, bookingReference: row['bookingReference'] as String, clientId: row['clientId'] as String, client: row['client'] as String, motelId: row['motelId'] as String, motel: row['motel'] as String, roomId: row['roomId'] as String, room: row['room'] as String, reservationDate: _subscriptionDateConverter.decode(row['reservationDate'] as int), amount: row['amount'] as int, status: _paymentStatusConverter.decode(row['status'] as String), method: _paymentMethodConverter.decode(row['method'] as String?), paymentMethodId: row['paymentMethodId'] as int?, paidAt: _paymentOptionalDateConverter.decode(row['paidAt'] as int?), receiptNumber: row['receiptNumber'] as String?),
        arguments: [clientId]);
  }

  @override
  Future<List<PaymentRecord>> findByMotel(String motelId) async {
    return _queryAdapter.queryList(
        'SELECT * FROM payments WHERE motelId = ?1 ORDER BY reservationDate DESC, id DESC',
        mapper: (Map<String, Object?> row) => PaymentRecord(id: row['id'] as String, bookingId: row['bookingId'] as String, bookingReference: row['bookingReference'] as String, clientId: row['clientId'] as String, client: row['client'] as String, motelId: row['motelId'] as String, motel: row['motel'] as String, roomId: row['roomId'] as String, room: row['room'] as String, reservationDate: _subscriptionDateConverter.decode(row['reservationDate'] as int), amount: row['amount'] as int, status: _paymentStatusConverter.decode(row['status'] as String), method: _paymentMethodConverter.decode(row['method'] as String?), paymentMethodId: row['paymentMethodId'] as int?, paidAt: _paymentOptionalDateConverter.decode(row['paidAt'] as int?), receiptNumber: row['receiptNumber'] as String?),
        arguments: [motelId]);
  }

  @override
  Future<List<PaymentCatalogEntry>> findCatalogEntries() async {
    return _queryAdapter.queryList(
        'SELECT * FROM payment_method_catalog ORDER BY id',
        mapper: (Map<String, Object?> row) => PaymentCatalogEntry(
            id: row['id'] as int, name: row['name'] as String));
  }

  @override
  Future<void> updatePendingPayment(
    String id,
    String motelId,
    int paymentMethodId,
    DateTime paidAt,
    String receiptNumber,
  ) async {
    await _queryAdapter.queryNoReturn(
        'UPDATE payments SET status = \'paid\', method = NULL, paymentMethodId = ?3, paidAt = ?4, receiptNumber = ?5 WHERE id = ?1 AND motelId = ?2 AND status = \'pending\' AND EXISTS (SELECT 1 FROM payment_method_catalog WHERE id = ?3)',
        arguments: [
          id,
          motelId,
          paymentMethodId,
          _subscriptionDateConverter.encode(paidAt),
          receiptNumber
        ]);
  }

  @override
  Future<int?> findAffectedRows() async {
    return _queryAdapter.query('SELECT changes()',
        mapper: (Map<String, Object?> row) => row.values.first as int);
  }

  @override
  Future<void> insertPayment(PaymentRecord payment) async {
    await _paymentRecordInsertionAdapter.insert(
        payment, OnConflictStrategy.abort);
  }

  @override
  Future<void> insertMissingDemoPayments(List<PaymentRecord> payments) async {
    await _paymentRecordInsertionAdapter.insertList(
        payments, OnConflictStrategy.ignore);
  }

  @override
  Future<void> insertCatalogEntries(List<PaymentCatalogEntry> entries) async {
    await _paymentCatalogEntryInsertionAdapter.insertList(
        entries, OnConflictStrategy.ignore);
  }

  @override
  Future<void> updateCatalogEntries(List<PaymentCatalogEntry> entries) async {
    await _paymentCatalogEntryUpdateAdapter.updateList(
        entries, OnConflictStrategy.abort);
  }

  @override
  Future<void> saveCatalogEntries(List<PaymentCatalogEntry> entries) async {
    if (database is sqflite.Transaction) {
      await super.saveCatalogEntries(entries);
    } else {
      await (database as sqflite.Database)
          .transaction<void>((transaction) async {
        final transactionDatabase = _$AppDatabase(changeListener)
          ..database = transaction;
        await transactionDatabase.paymentDao.saveCatalogEntries(entries);
      });
    }
  }

  @override
  Future<int> registerLocalPayment(
    String id,
    String motelId,
    int paymentMethodId,
    DateTime paidAt,
    String receiptNumber,
  ) async {
    if (database is sqflite.Transaction) {
      return super.registerLocalPayment(
          id, motelId, paymentMethodId, paidAt, receiptNumber);
    } else {
      return (database as sqflite.Database)
          .transaction<int>((transaction) async {
        final transactionDatabase = _$AppDatabase(changeListener)
          ..database = transaction;
        return transactionDatabase.paymentDao.registerLocalPayment(
            id, motelId, paymentMethodId, paidAt, receiptNumber);
      });
    }
  }
}

class _$ClientDao extends ClientDao {
  _$ClientDao(
    this.database,
    this.changeListener,
  )   : _queryAdapter = QueryAdapter(database),
        _clientEntryInsertionAdapter = InsertionAdapter(
            database,
            'clients',
            (ClientEntry item) => <String, Object?>{
                  'id': item.id,
                  'name': item.name,
                  'phone': item.phone,
                  'email': item.email,
                  'country_code': item.countryCode,
                  'password': item.password
                }),
        _clientEntryUpdateAdapter = UpdateAdapter(
            database,
            'clients',
            ['id'],
            (ClientEntry item) => <String, Object?>{
                  'id': item.id,
                  'name': item.name,
                  'phone': item.phone,
                  'email': item.email,
                  'country_code': item.countryCode,
                  'password': item.password
                }),
        _clientEntryDeletionAdapter = DeletionAdapter(
            database,
            'clients',
            ['id'],
            (ClientEntry item) => <String, Object?>{
                  'id': item.id,
                  'name': item.name,
                  'phone': item.phone,
                  'email': item.email,
                  'country_code': item.countryCode,
                  'password': item.password
                });

  final sqflite.DatabaseExecutor database;

  final StreamController<String> changeListener;

  final QueryAdapter _queryAdapter;

  final InsertionAdapter<ClientEntry> _clientEntryInsertionAdapter;

  final UpdateAdapter<ClientEntry> _clientEntryUpdateAdapter;

  final DeletionAdapter<ClientEntry> _clientEntryDeletionAdapter;

  @override
  Future<ClientEntry?> findById(int id) async {
    return _queryAdapter.query('SELECT * FROM clients WHERE id = ?1 LIMIT 1',
        mapper: (Map<String, Object?> row) => ClientEntry(
            id: row['id'] as int?,
            name: row['name'] as String,
            phone: row['phone'] as String,
            email: row['email'] as String,
            countryCode: row['country_code'] as String,
            password: row['password'] as String),
        arguments: [id]);
  }

  @override
  Future<List<ClientEntry>> findAll() async {
    return _queryAdapter.queryList('SELECT * FROM clients',
        mapper: (Map<String, Object?> row) => ClientEntry(
            id: row['id'] as int?,
            name: row['name'] as String,
            phone: row['phone'] as String,
            email: row['email'] as String,
            countryCode: row['country_code'] as String,
            password: row['password'] as String));
  }

  @override
  Future<void> deleteById(int id) async {
    await _queryAdapter
        .queryNoReturn('DELETE FROM clients WHERE id = ?1', arguments: [id]);
  }

  @override
  Future<int> insertClient(ClientEntry client) {
    return _clientEntryInsertionAdapter.insertAndReturnId(
        client, OnConflictStrategy.abort);
  }

  @override
  Future<void> insertClients(List<ClientEntry> clients) async {
    await _clientEntryInsertionAdapter.insertList(
        clients, OnConflictStrategy.replace);
  }

  @override
  Future<int> updateClient(ClientEntry client) {
    return _clientEntryUpdateAdapter.updateAndReturnChangedRows(
        client, OnConflictStrategy.abort);
  }

  @override
  Future<int> deleteClient(ClientEntry client) {
    return _clientEntryDeletionAdapter.deleteAndReturnChangedRows(client);
  }
}

class _$PhoneCountryCodeDao extends PhoneCountryCodeDao {
  _$PhoneCountryCodeDao(
    this.database,
    this.changeListener,
  )   : _queryAdapter = QueryAdapter(database),
        _phoneCountryCodeInsertionAdapter = InsertionAdapter(
            database,
            'phone_country_codes',
            (PhoneCountryCode item) => <String, Object?>{
                  'id': item.id,
                  'country_code': item.countryCode,
                  'country_name': item.countryName,
                  'calling_code': item.callingCode,
                  'active': item.active ? 1 : 0
                });

  final sqflite.DatabaseExecutor database;

  final StreamController<String> changeListener;

  final QueryAdapter _queryAdapter;

  final InsertionAdapter<PhoneCountryCode> _phoneCountryCodeInsertionAdapter;

  @override
  Future<List<PhoneCountryCode>> findAll() async {
    return _queryAdapter.queryList('SELECT * FROM phone_country_codes',
        mapper: (Map<String, Object?> row) => PhoneCountryCode(
            id: row['id'] as int,
            countryCode: row['country_code'] as String,
            countryName: row['country_name'] as String,
            callingCode: row['calling_code'] as String,
            active: (row['active'] as int) != 0));
  }

  @override
  Future<List<PhoneCountryCode>> findActive() async {
    return _queryAdapter.queryList(
        'SELECT * FROM phone_country_codes WHERE active = 1',
        mapper: (Map<String, Object?> row) => PhoneCountryCode(
            id: row['id'] as int,
            countryCode: row['country_code'] as String,
            countryName: row['country_name'] as String,
            callingCode: row['calling_code'] as String,
            active: (row['active'] as int) != 0));
  }

  @override
  Future<void> deleteAll() async {
    await _queryAdapter.queryNoReturn('DELETE FROM phone_country_codes');
  }

  @override
  Future<void> insertCountryCodes(List<PhoneCountryCode> codes) async {
    await _phoneCountryCodeInsertionAdapter.insertList(
        codes, OnConflictStrategy.replace);
  }
}

// ignore_for_file: unused_element
final _subscriptionDateConverter = SubscriptionDateConverter();
final _subscriptionStatusConverter = SubscriptionStatusConverter();
final _subscriptionFeaturesConverter = SubscriptionFeaturesConverter();
final _paymentStatusConverter = PaymentStatusConverter();
final _paymentMethodConverter = PaymentMethodConverter();
final _paymentOptionalDateConverter = PaymentOptionalDateConverter();
