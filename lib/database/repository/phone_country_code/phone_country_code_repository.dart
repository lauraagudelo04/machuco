import 'package:floor/floor.dart';
import 'package:machuco/database/model/phone_country_code/phone_country_code.dart';

@dao
abstract class PhoneCountryCodeDao {
  @Query('SELECT * FROM phone_country_codes')
  Future<List<PhoneCountryCode>> findAll();

  @Query('SELECT * FROM phone_country_codes WHERE active = 1')
  Future<List<PhoneCountryCode>> findActive();

  @Insert(onConflict: OnConflictStrategy.replace)
  Future<void> insertCountryCodes(List<PhoneCountryCode> codes);

  @Query('DELETE FROM phone_country_codes')
  Future<void> deleteAll();
}