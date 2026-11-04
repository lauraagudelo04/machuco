import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:machuco/database/app_database.dart';
import 'package:machuco/database/repository/auth/auth_catalog_dao.dart';
import 'package:machuco/models/auth/country_phone_code.dart';
import 'package:machuco/service/auth/auth_preferences.dart';
import 'package:machuco/service/room/supabase_room_config.dart';
import 'package:sqflite/sqflite.dart' as sqflite;

class AuthCatalogRepositoryException implements Exception {
  const AuthCatalogRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Consulta los maestros de autenticación expuestos por Supabase (REST) con
/// caché local en SQLite, siguiendo el patrón de `RoomServiceRepository`.
class AuthCatalogRepository {
  AuthCatalogRepository({
    required this.baseUrl,
    required this.apiKey,
    required this.catalogDao,
    required this.preferences,
    http.Client? httpClient,
    DateTime Function()? clock,
    this.cacheTtl = const Duration(hours: 24),
  }) : _httpClient = httpClient ?? http.Client(),
       _clock = clock ?? DateTime.now;

  /// Usa `SUPABASE_URL` / `SUPABASE_ANON_KEY` (`--dart-define`) y la base de
  /// datos común de la app.
  factory AuthCatalogRepository.fromEnvironment({
    AuthPreferences? preferences,
  }) {
    return AuthCatalogRepository(
      baseUrl: SupabaseRoomConfig.baseUrl,
      apiKey: SupabaseRoomConfig.apiKey,
      catalogDao: AuthCatalogDao(
        () async =>
            (await AppDatabaseProvider.database).database as sqflite.Database,
      ),
      preferences: preferences ?? AuthPreferences(),
    );
  }

  static const _countryPhoneCodesColumns =
      'id,iso_code,country_name,dial_code,flag_emoji,'
      'phone_min_length,phone_max_length,is_active,sort_order';

  final String baseUrl;
  final String apiKey;
  final AuthCatalogDao catalogDao;
  final AuthPreferences preferences;
  final Duration cacheTtl;
  final http.Client _httpClient;
  final DateTime Function() _clock;

  bool get isConfigured =>
      baseUrl.trim().isNotEmpty && apiKey.trim().isNotEmpty;

  /// Indicativos activos ordenados por `sort_order`.
  ///
  /// Devuelve la caché de SQLite si existe y no supera [cacheTtl]; si no,
  /// consulta Supabase y actualiza la caché. Sin Supabase configurado y sin
  /// caché, devuelve la semilla de desarrollo (Colombia +57).
  Future<List<CountryPhoneCode>> getCountryPhoneCodes({
    bool forceRefresh = false,
  }) async {
    final cached = await _readCache();
    if (!forceRefresh && cached.isNotEmpty && await _isCacheFresh()) {
      return cached;
    }

    if (!isConfigured) {
      return cached.isNotEmpty
          ? cached
          : const [developmentCountryPhoneCodeSeed];
    }

    try {
      final uri =
          Uri.parse(
            '${baseUrl.replaceFirst(RegExp(r'/$'), '')}/rest/v1/country_phone_codes',
          ).replace(
            queryParameters: {
              'select': _countryPhoneCodesColumns,
              'is_active': 'eq.true',
              'order': 'sort_order.asc',
            },
          );
      final response = await _httpClient.get(
        uri,
        headers: {'apikey': apiKey, 'Accept': 'application/json'},
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return _cachedOrThrow(
          cached,
          'Supabase respondió con estado ${response.statusCode}',
        );
      }

      final decoded =
          jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>;
      final codes =
          decoded
              .map(
                (item) => CountryPhoneCode.fromMap(
                  Map<String, Object?>.from(item as Map),
                ),
              )
              .where((code) => code.isActive)
              .toList(growable: false)
            ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      await catalogDao.replaceCountryPhoneCodes(codes);
      await preferences.saveCatalogsSyncedAt(_clock());
      return codes;
    } on AuthCatalogRepositoryException {
      rethrow;
    } catch (_) {
      return _cachedOrThrow(cached, 'No fue posible consultar Supabase');
    }
  }

  Future<List<CountryPhoneCode>> _readCache() async {
    try {
      return await catalogDao.getActiveCountryPhoneCodes();
    } catch (_) {
      return const [];
    }
  }

  Future<bool> _isCacheFresh() async {
    try {
      final syncedAt = await preferences.loadCatalogsSyncedAt();
      return syncedAt != null && _clock().difference(syncedAt) < cacheTtl;
    } catch (_) {
      return false;
    }
  }

  List<CountryPhoneCode> _cachedOrThrow(
    List<CountryPhoneCode> cached,
    String message,
  ) {
    if (cached.isNotEmpty) return cached;
    throw AuthCatalogRepositoryException(message);
  }
}
