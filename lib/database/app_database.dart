import 'dart:async';

import 'package:floor/floor.dart';
import 'package:machuco/models/booking/reservation_category.dart';
import 'package:machuco/repositories/booking/reservation_category_dao.dart';
// sqflite is a transitive dependency of floor, required by generated code.
// ignore: depend_on_referenced_packages
import 'package:sqflite/sqflite.dart' as sqflite;

part 'app_database.g.dart';

/// Local SQLite database (Floor). Each module adds its entities and DAO
/// getters here and bumps [version] with a migration when needed.
@Database(version: 1, entities: [ReservationCategory])
abstract class AppDatabase extends FloorDatabase {
  static const String fileName = 'machuco.db';

  static Future<AppDatabase>? _instance;

  /// Lazily opens the shared database once.
  static Future<AppDatabase> instance() {
    return _instance ??= $FloorAppDatabase.databaseBuilder(fileName).build();
  }

  ReservationCategoryDao get reservationCategoryDao;
}
