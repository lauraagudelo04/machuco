import 'package:machuco/database/repository/room/room_dao.dart'
    show DatabaseProvider;
import 'package:machuco/models/auth/country_phone_code.dart';
import 'package:sqflite/sqflite.dart';

/// Data Access Object de los maestros de autenticación sobre SQLite.
class AuthCatalogDao {
  AuthCatalogDao(this._databaseProvider);

  final DatabaseProvider _databaseProvider;

  Future<List<CountryPhoneCode>> getActiveCountryPhoneCodes() async {
    final database = await _databaseProvider();
    final rows = await database.query(
      'country_phone_codes',
      where: 'is_active = ?',
      whereArgs: [1],
      orderBy: 'sort_order ASC, country_name ASC',
    );
    return rows.map(CountryPhoneCode.fromMap).toList(growable: false);
  }

  /// Reemplaza la caché completa: los registros que ya no llegan desde
  /// Supabase (p. ej. marcados como inactivos) desaparecen de los selectores.
  Future<void> replaceCountryPhoneCodes(List<CountryPhoneCode> codes) async {
    final database = await _databaseProvider();
    await database.transaction((transaction) async {
      await transaction.delete('country_phone_codes');
      for (final code in codes) {
        await transaction.insert(
          'country_phone_codes',
          code.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<void> clear() async {
    final database = await _databaseProvider();
    await database.delete('country_phone_codes');
  }
}
