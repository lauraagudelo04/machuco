import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:floor/floor.dart';
import 'package:machuco/database/app_database.dart';
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

class CountryCodeRepository {
  CountryCodeRepository({
    AppDatabase? database,
    http.Client? httpClient,
    String? supabaseUrl,
    String? publishableKey,
  })  : _database = database == null
            ? AppDatabaseProvider.database
            : Future.value(database),
        _get = httpClient?.get ?? http.get,
        _supabaseUrl = supabaseUrl ??
            const String.fromEnvironment(
              'SUPABASE_URL',
              defaultValue: 'https://ogrbbuwtsyezegkpwtsl.supabase.co',
            ),
        _publishableKey = publishableKey ??
            const String.fromEnvironment(
              'SUPABASE_PUBLISHABLE_KEY',
              defaultValue: 'sb_publishable_Wv16MVxsTzA89lBeocarLQ_YL33Ya_E',
            );

  final Future<AppDatabase> _database;
  final Future<http.Response> Function(Uri, {Map<String, String>? headers}) _get;
  final String _supabaseUrl;
  final String _publishableKey;

  Future<void> _syncCountryCodes() async {
    final uri = Uri.parse('$_supabaseUrl/rest/v1/phone_country_codes?select=*&order=id.asc');
    try {
      final response = await _get(
        uri,
        headers: {'apikey': _publishableKey, 'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final List<dynamic> rows = jsonDecode(utf8.decode(response.bodyBytes));
        final codes = rows
            .map((row) => PhoneCountryCode.fromJson(row as Map<String, dynamic>))
            .toList();

        final dao = (await _database).phoneCountryCodeDao;
        await dao.insertCountryCodes(codes);
      }
    } catch (e) {
      print('Sincronización de códigos fallida (Offline): $e');
    }
  }

  Future<List<PhoneCountryCode>> getAllCountryCodes() async {
    await _syncCountryCodes();
    final dao = (await _database).phoneCountryCodeDao;
    return await dao.findAll();
  }

  Future<List<PhoneCountryCode>> getActiveCountryCodes() async {
    try {
      final uri = Uri.parse('$_supabaseUrl/rest/v1/phone_country_codes?active=eq.true');
      
      final response = await http.get(
        uri,
        headers: {
          'apikey': _publishableKey,
          'Content-Type': 'application/json'
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> responseData = jsonDecode(utf8.decode(response.bodyBytes));
        
        final serverCodes = responseData.map((json) => PhoneCountryCode(
          id: json['id'] as int,
          countryCode: json['country_code'] as String,
          countryName: json['country_name'] as String,
          callingCode: json['calling_code'] as String,
          active: json['active'] as bool,
        )).toList();

        final dao = (await _database).phoneCountryCodeDao;
        await dao.insertCountryCodes(serverCodes); 
      }
    } catch (e) {
      print('Sin conexión o error al descargar country codes: $e');
    }

    final dao = (await _database).phoneCountryCodeDao;
    return await dao.findActive(); 
  }

  Future<void> saveCountryCodes(List<PhoneCountryCode> codes) async {
    final dao = (await _database).phoneCountryCodeDao;
    await dao.insertCountryCodes(codes);
  }
}