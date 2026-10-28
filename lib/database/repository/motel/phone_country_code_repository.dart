import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:machuco/database/repository/motel/phone_country_code_dao.dart';
import 'package:machuco/models/phone_country_code/phone_country_code.dart';

class PhoneCountryCodeRepositoryException implements Exception {
  const PhoneCountryCodeRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Consulta el maestro de códigos telefónicos de país expuesto por Supabase
/// y lo cachea en SQLite para poder usarlo sin conexión.
class PhoneCountryCodeRepository {
  PhoneCountryCodeRepository({
    required this.baseUrl,
    required this.apiKey,
    required this.countryCodeDao,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  final String baseUrl;
  final String apiKey;
  final PhoneCountryCodeDao countryCodeDao;
  final http.Client _httpClient;

  Future<List<PhoneCountryCode>> getCountryCodes({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final cached = await countryCodeDao.getCountryCodes();
      if (cached.isNotEmpty) return cached;
    }

    if (baseUrl.trim().isEmpty || apiKey.trim().isEmpty) {
      return _cachedOrThrow('Supabase no está configurado');
    }

    try {
      final uri = Uri.parse(
        '${baseUrl.replaceFirst(RegExp(r'/$'), '')}/rest/v1/phone_country_codes',
      ).replace(queryParameters: {'select': '*', 'order': 'id.asc'});
      final response = await _httpClient.get(
        uri,
        headers: {'apikey': apiKey, 'Accept': 'application/json'},
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return _cachedOrThrow(
          'Supabase respondió con estado ${response.statusCode}',
        );
      }

      final decoded = jsonDecode(response.body) as List<dynamic>;
      final countryCodes = decoded
          .map(
            (item) => PhoneCountryCode.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(growable: false);
      await countryCodeDao.saveCountryCodes(countryCodes);
      return countryCodes;
    } on PhoneCountryCodeRepositoryException {
      rethrow;
    } catch (_) {
      return _cachedOrThrow('No fue posible consultar Supabase');
    }
  }

  Future<List<PhoneCountryCode>> _cachedOrThrow(String message) async {
    final cached = await countryCodeDao.getCountryCodes();
    if (cached.isNotEmpty) return cached;
    throw PhoneCountryCodeRepositoryException(message);
  }
}
