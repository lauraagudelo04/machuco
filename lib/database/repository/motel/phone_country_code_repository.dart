import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:machuco/database/model/phone_country_code/phone_country_code.dart';
import 'package:machuco/database/repository/phone_country_code/phone_country_code_repository.dart';

class PhoneCountryCodeRepositoryException implements Exception {
  const PhoneCountryCodeRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Consulta el maestro de códigos telefónicos de país expuesto por Supabase
/// y lo cachea en SQLite (DAO Floor compartido `PhoneCountryCodeDao`).
class PhoneCountryCodeRepository {
  PhoneCountryCodeRepository({
    required this.baseUrl,
    required this.apiKey,
    required Future<PhoneCountryCodeDao> Function() daoProvider,
    http.Client? httpClient,
  }) : _daoProvider = daoProvider,
       _httpClient = httpClient ?? http.Client();

  final String baseUrl;
  final String apiKey;
  final Future<PhoneCountryCodeDao> Function() _daoProvider;
  final http.Client _httpClient;

  Future<List<PhoneCountryCode>> getCountryCodes({
    bool forceRefresh = false,
  }) async {
    final dao = await _daoProvider();

    if (!forceRefresh) {
      final cached = await _readCache(dao);
      if (cached.isNotEmpty) return cached;
    }

    if (baseUrl.trim().isEmpty || apiKey.trim().isEmpty) {
      return _cachedOrThrow(dao, 'Supabase no está configurado');
    }

    try {
      final uri = Uri.parse(
        '${baseUrl.replaceFirst(RegExp(r'/$'), '')}/rest/v1/phone_country_codes',
      ).replace(
        queryParameters: {
          'select': 'id,country_code,country_name,calling_code,active',
          'active': 'eq.true',
          'order': 'country_name.asc',
        },
      );
      final response = await _httpClient.get(
        uri,
        headers: {'apikey': apiKey, 'Accept': 'application/json'},
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return _cachedOrThrow(
          dao,
          'Supabase respondió con estado ${response.statusCode}',
        );
      }

      // Se decodifica como UTF-8 para no dañar tildes (México, Perú...).
      final decoded =
          jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>;
      final countryCodes = decoded
          .map(
            (item) => PhoneCountryCode.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList();

      await dao.deleteAll();
      await dao.insertCountryCodes(countryCodes);
      return _sorted(countryCodes);
    } on PhoneCountryCodeRepositoryException {
      rethrow;
    } catch (_) {
      return _cachedOrThrow(dao, 'No fue posible consultar Supabase');
    }
  }

  Future<List<PhoneCountryCode>> _readCache(PhoneCountryCodeDao dao) async =>
      _sorted(await dao.findActive());

  Future<List<PhoneCountryCode>> _cachedOrThrow(
    PhoneCountryCodeDao dao,
    String message,
  ) async {
    final cached = await _readCache(dao);
    if (cached.isNotEmpty) return cached;
    throw PhoneCountryCodeRepositoryException(message);
  }

  List<PhoneCountryCode> _sorted(List<PhoneCountryCode> codes) =>
      List.of(codes)..sort(
        (a, b) =>
            a.countryName.toLowerCase().compareTo(b.countryName.toLowerCase()),
      );
}