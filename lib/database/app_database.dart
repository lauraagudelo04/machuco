import 'dart:async';

import 'package:floor/floor.dart';
import 'package:machuco/models/booking/reservation_category.dart';
import 'package:machuco/models/booking/reservation_entity.dart';
import 'package:machuco/models/booking/reservation_line_item_entity.dart';
import 'package:machuco/repositories/booking/reservation_category_dao.dart';
import 'package:machuco/repositories/booking/reservation_dao.dart';
// sqflite is a transitive dependency of floor, required by generated code.
// ignore: depend_on_referenced_packages
import 'package:sqflite/sqflite.dart' as sqflite;

part 'app_database.g.dart';

/// Local SQLite database (Floor). Each module adds its entities and DAO
/// getters here and bumps [version] with a migration when needed.
@Database(
  version: 2,
  entities: [ReservationCategory, ReservationEntity, ReservationLineItemEntity],
)
abstract class AppDatabase extends FloorDatabase {
  static const String fileName = 'machuco.db';

  static Future<AppDatabase>? _instance;

  /// Lazily opens the shared database once.
  static Future<AppDatabase> instance() {
    return _instance ??= $FloorAppDatabase
        .databaseBuilder(fileName)
        .addMigrations([migration1to2])
        .build();
  }

  /// v1 -> v2: adds the reservations tables. Must match the generated
  /// `CREATE TABLE` statements of the entities.
  static final Migration migration1to2 = Migration(1, 2, (database) async {
    await database.execute(
      'CREATE TABLE IF NOT EXISTS `reservations` (`id` TEXT NOT NULL, '
      '`requestId` TEXT NOT NULL, `motelId` TEXT NOT NULL, '
      '`motelName` TEXT NOT NULL, `roomId` TEXT NOT NULL, '
      '`roomName` TEXT NOT NULL, `roomNumber` TEXT NOT NULL, '
      '`checkIn` INTEGER NOT NULL, `checkOut` INTEGER NOT NULL, '
      '`stayMode` TEXT NOT NULL, `guestCount` INTEGER NOT NULL, '
      '`roomTotal` INTEGER NOT NULL, `total` INTEGER NOT NULL, '
      '`status` TEXT NOT NULL, `createdAt` INTEGER NOT NULL, '
      '`guestId` TEXT NOT NULL, `guestName` TEXT NOT NULL, '
      '`categoryId` INTEGER, `cancellationReason` TEXT, '
      '`invoiceAccessStatus` TEXT NOT NULL, `paymentMethod` TEXT, '
      'PRIMARY KEY (`id`))',
    );
    await database.execute(
      'CREATE TABLE IF NOT EXISTS `reservation_line_items` ('
      '`rowId` INTEGER PRIMARY KEY AUTOINCREMENT, '
      '`reservationId` TEXT NOT NULL, `kind` TEXT NOT NULL, '
      '`itemId` TEXT NOT NULL, `name` TEXT NOT NULL, '
      '`unitPrice` INTEGER NOT NULL, `quantity` INTEGER NOT NULL, '
      '`position` INTEGER NOT NULL, '
      'FOREIGN KEY (`reservationId`) REFERENCES `reservations` (`id`) '
      'ON UPDATE NO ACTION ON DELETE CASCADE)',
    );
    await database.execute(
      'CREATE INDEX IF NOT EXISTS `index_reservations_requestId` '
      'ON `reservations` (`requestId`)',
    );
    await database.execute(
      'CREATE INDEX IF NOT EXISTS `index_reservations_motelId` '
      'ON `reservations` (`motelId`)',
    );
    await database.execute(
      'CREATE INDEX IF NOT EXISTS `index_reservation_line_items_reservationId` '
      'ON `reservation_line_items` (`reservationId`)',
    );
  });

  ReservationCategoryDao get reservationCategoryDao;

  ReservationDao get reservationDao;
}
