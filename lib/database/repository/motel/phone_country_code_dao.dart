import 'package:machuco/models/phone_country_code/phone_country_code.dart';
import 'package:sqflite/sqflite.dart';

typedef DatabaseProvider = Future<Database> Function();

/// Data Access Object del maestro de códigos telefónicos de país sobre SQLite.
class PhoneCountryCodeDao {
  PhoneCountryCodeDao(this._databaseProvider);

  final DatabaseProvider _databaseProvider;

  Future<List<PhoneCountryCode>> getCountryCodes() async {
    final database = await _databaseProvider();
    final rows = await database.query(
      'phone_country_codes',
      orderBy: 'country_name COLLATE NOCASE ASC',
    );
    return rows.map(_fromMap).toList(growable: false);
  }

  Future<void> saveCountryCodes(List<PhoneCountryCode> countryCodes) async {
    final database = await _databaseProvider();
    await database.transaction((transaction) async {
      await transaction.delete('phone_country_codes');
      for (final countryCode in countryCodes) {
        await transaction.insert(
          'phone_country_codes',
          _toMap(countryCode),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<void> clear() async {
    final database = await _databaseProvider();
    await database.delete('phone_country_codes');
  }

  PhoneCountryCode _fromMap(Map<String, Object?> map) => PhoneCountryCode(
    id: map['id']! as int,
    countryCode: map['country_code']! as String,
    countryName: map['country_name']! as String,
    callingCode: map['calling_code']! as String,
    // SQLite no tiene booleanos: se guarda como 1 (activo) o 0 (inactivo).
    active: (map['active'] as int? ?? 1) == 1,
  );

  Map<String, Object?> _toMap(PhoneCountryCode countryCode) => {
    'id': countryCode.id,
    'country_code': countryCode.countryCode,
    'country_name': countryCode.countryName,
    'calling_code': countryCode.callingCode,
    'active': countryCode.active ? 1 : 0,
  };
}
