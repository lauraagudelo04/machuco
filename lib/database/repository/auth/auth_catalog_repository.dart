import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:machuco/database/app_database.dart';
import 'package:machuco/database/model/document_type/document_type_entry.dart';
import 'package:machuco/database/model/phone_country_code/phone_country_code.dart';
import 'package:machuco/database/repository/phone_country_code/phone_country_code_repository.dart';
import 'package:machuco/models/auth/country_phone_code.dart';
import 'package:machuco/models/auth/document_type.dart';
import 'package:machuco/models/auth/subscription_plan_option.dart';
import 'package:machuco/service/auth/auth_preferences.dart';
import 'package:machuco/service/phone_country_code/supabase_phone_country_code_config.dart';

class AuthCatalogRepositoryException implements Exception {
  const AuthCatalogRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Maestros del módulo de autenticación: indicativos telefónicos por país.
///
/// Sigue el patrón de `ClientRepository`: consulta la tabla
/// `phone_country_codes` de Supabase por REST, la guarda en SQLite con el DAO
/// Floor compartido [PhoneCountryCodeDao] y siempre responde desde SQLite,
/// así la app funciona sin conexión cuando ya hay caché.
class AuthCatalogRepository {
  AuthCatalogRepository({
    AppDatabase? database,
    http.Client? httpClient,
    String? supabaseUrl,
    String? publishableKey,
    AuthPreferences? preferences,
    DateTime Function()? clock,
    this.cacheTtl = const Duration(hours: 24),
  }) : _injectedDatabase = database,
       _get = httpClient?.get ?? http.get,
       _supabaseUrl = supabaseUrl ?? SupabasePhoneCountryCodeConfig.baseUrl,
       _publishableKey =
           publishableKey ?? SupabasePhoneCountryCodeConfig.apiKey,
       _preferences = preferences ?? AuthPreferences(),
       _clock = clock ?? DateTime.now;

  /// Usa `SUPABASE_URL` / `SUPABASE_ANON_KEY` (`--dart-define`) y la base de
  /// datos común de la app.
  factory AuthCatalogRepository.fromEnvironment({
    AuthPreferences? preferences,
  }) => AuthCatalogRepository(preferences: preferences);

  static const _table = 'phone_country_codes';
  // `*` y no una lista: `phone_min_length` y `phone_max_length` pueden no
  // existir todavía en la tabla y pedir una columna ausente haría fallar la
  // consulta completa (HTTP 400).
  static const _columns = '*';

  final AppDatabase? _injectedDatabase;
  final Future<http.Response> Function(Uri, {Map<String, String>? headers})
  _get;
  final String _supabaseUrl;
  final String _publishableKey;
  final AuthPreferences _preferences;
  final DateTime Function() _clock;
  final Duration cacheTtl;

  // Caché en memoria de los planes (sin tabla SQLite nueva).
  List<SubscriptionPlanOption>? _plansCache;
  DateTime? _plansCachedAt;

  // Caché en memoria de los tipos de documento; el respaldo sin red es la
  // tabla `document_types` que ya tiene AppDatabase.
  List<DocumentTypeOption>? _documentTypesCache;
  DateTime? _documentTypesCachedAt;

  bool get isConfigured =>
      _supabaseUrl.trim().isNotEmpty && _publishableKey.trim().isNotEmpty;

  // La base se abre de forma perezosa para que construir el repositorio (p. ej.
  // un fake en pruebas) no abra SQLite.
  Future<PhoneCountryCodeDao> _dao() async =>
      (_injectedDatabase ?? await AppDatabaseProvider.database)
          .phoneCountryCodeDao;

  /// Indicativos activos registrados en Supabase, ordenados por nombre.
  ///
  /// Devuelve la caché de SQLite si existe y no supera [cacheTtl]; si no,
  /// sincroniza con Supabase y vuelve a leer SQLite. Sin Supabase configurado
  /// y sin caché, devuelve la semilla de desarrollo (Colombia +57).
  Future<List<CountryPhoneCode>> getCountryPhoneCodes({
    bool forceRefresh = false,
  }) async {
    final cached = await _readActive();
    if (!forceRefresh && cached.isNotEmpty && await _isCacheFresh()) {
      return cached;
    }

    if (!isConfigured) {
      return cached.isNotEmpty
          ? cached
          : const [developmentCountryPhoneCodeSeed];
    }

    final synced = await _syncCountryCodes();
    final codes = synced ? await _readActive() : cached;
    if (codes.isNotEmpty) return codes;

    throw AuthCatalogRepositoryException(
      synced
          ? 'No hay indicativos disponibles por ahora.'
          : 'No fue posible cargar los indicativos. Revisa tu conexión.',
    );
  }

  /// Planes de suscripción para el registro del propietario, leídos de
  /// Supabase `subscription_plans` (solo `is_active=eq.true`, ordenados por
  /// `sort_order`) con nombre, descripción, precio, periodicidad, máximo de
  /// moteles y características. Se cachean en memoria durante
  /// [cacheTtl]; si la red falla y hay caché, se devuelve esa caché.
  Future<List<SubscriptionPlanOption>> getSubscriptionPlans({
    bool forceRefresh = false,
  }) async {
    final cached = _plansCache;
    final cachedAt = _plansCachedAt;
    final isFresh =
        cached != null &&
        cachedAt != null &&
        _clock().difference(cachedAt) < cacheTtl;
    if (!forceRefresh && isFresh && cached.isNotEmpty) {
      return cached;
    }

    final fetched = isConfigured ? await _fetchSubscriptionPlans() : null;
    if (fetched != null && fetched.isNotEmpty) {
      _plansCache = fetched;
      _plansCachedAt = _clock();
      return fetched;
    }
    if (cached != null && cached.isNotEmpty) return cached;

    throw AuthCatalogRepositoryException(
      fetched == null
          ? 'No fue posible cargar los planes. Revisa tu conexión.'
          : 'No hay planes disponibles por ahora.',
    );
  }

  /// Tipos de documento que ofrece el registro (CC, CE y pasaporte), leídos de
  /// Supabase `document_types` (solo `is_active=eq.true`, por `sort_order`).
  ///
  /// Cachea en memoria durante [cacheTtl] y guarda la respuesta en la tabla
  /// `document_types` del [AppDatabase] (misma que usa el módulo de
  /// propietarios), que sirve de respaldo sin conexión. Lanza
  /// [AuthCatalogRepositoryException] si no hay ningún tipo disponible.
  Future<List<DocumentTypeOption>> getDocumentTypes({
    bool forceRefresh = false,
  }) async {
    final cached = _documentTypesCache;
    final cachedAt = _documentTypesCachedAt;
    if (!forceRefresh &&
        cached != null &&
        cached.isNotEmpty &&
        cachedAt != null &&
        _clock().difference(cachedAt) < cacheTtl) {
      return cached;
    }

    final fetched = isConfigured ? await _fetchDocumentTypes() : null;
    if (fetched != null) {
      await _saveDocumentTypes(fetched);
    }
    final options = _offered(fetched ?? await _readDocumentTypes());
    if (options.isNotEmpty) {
      _documentTypesCache = options;
      _documentTypesCachedAt = _clock();
      return options;
    }
    if (cached != null && cached.isNotEmpty) return cached;

    throw AuthCatalogRepositoryException(
      fetched == null
          ? 'No fue posible cargar los tipos de documento. Revisa tu conexión.'
          : 'No hay tipos de documento disponibles por ahora.',
    );
  }

  /// Solo los tipos que el registro acepta y que `firestore.rules` conoce.
  List<DocumentTypeOption> _offered(List<DocumentTypeOption> all) => [
    for (final option in all)
      if (option.isOfferedInRegistration) option,
  ]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

  /// `null` si no pudo consultar; lista (posiblemente vacía) si respondió.
  Future<List<DocumentTypeOption>?> _fetchDocumentTypes() async {
    final base = Uri.tryParse(_supabaseUrl.trim());
    if (base == null || base.scheme != 'https' || base.host.isEmpty) {
      debugPrint('Supabase no configurado: no se cargan los documentos.');
      return null;
    }
    final uri = base.replace(
      path: '/rest/v1/document_types',
      queryParameters: {
        'select': 'id,code,name,pattern,example,sort_order',
        'is_active': 'eq.true',
        'order': 'sort_order.asc',
      },
    );
    try {
      final response = await _get(
        uri,
        headers: {'apikey': _publishableKey, 'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        debugPrint('Supabase respondió ${response.statusCode} a documentos.');
        return null;
      }
      final rows = jsonDecode(utf8.decode(response.bodyBytes));
      if (rows is! List) throw const FormatException('Respuesta inválida');
      return [
        for (final row in rows)
          if (row is Map)
            ?DocumentTypeOption.tryFromJson(Map<String, dynamic>.from(row)),
      ];
    } on FormatException {
      debugPrint('El JSON de tipos de documento está malformado.');
    } catch (error) {
      debugPrint('No fue posible consultar los tipos de documento: $error');
    }
    return null;
  }

  /// Reemplaza la tabla local solo si la respuesta trae tipos: un maestro
  /// vacío es más probable que sea un despliegue incompleto que un retiro.
  Future<void> _saveDocumentTypes(List<DocumentTypeOption> options) async {
    if (options.isEmpty) return;
    try {
      final dao = (_injectedDatabase ?? await AppDatabaseProvider.database)
          .documentTypeDao;
      await dao.deleteAll();
      await dao.insertDocumentTypes([
        for (final option in options)
          DocumentTypeEntry(
            id: option.id,
            code: option.code,
            name: option.name,
            pattern: option.pattern,
            example: option.example,
            isActive: 1,
            sortOrder: option.sortOrder,
          ),
      ]);
    } catch (error) {
      debugPrint('No fue posible guardar los tipos de documento: $error');
    }
  }

  Future<List<DocumentTypeOption>> _readDocumentTypes() async {
    try {
      final dao = (_injectedDatabase ?? await AppDatabaseProvider.database)
          .documentTypeDao;
      return [
        for (final entry in await dao.findActive())
          DocumentTypeOption.fromEntry(entry),
      ];
    } catch (error) {
      debugPrint('No fue posible leer los tipos de documento: $error');
      return const [];
    }
  }

  /// `null` si no pudo consultar; lista (posiblemente vacía) si respondió.
  Future<List<SubscriptionPlanOption>?> _fetchSubscriptionPlans() async {
    final base = Uri.tryParse(_supabaseUrl.trim());
    if (base == null || base.scheme != 'https' || base.host.isEmpty) {
      debugPrint('Supabase no configurado: no se cargan los planes.');
      return null;
    }
    final uri = base.replace(
      path: '/rest/v1/subscription_plans',
      queryParameters: {
        'select':
            'id,name,description,price,currency,billing_period,features,'
            'max_motels,sort_order',
        'is_active': 'eq.true',
        'order': 'sort_order.asc',
      },
    );
    try {
      final response = await _get(
        uri,
        headers: {'apikey': _publishableKey, 'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        debugPrint('Supabase respondió ${response.statusCode} a planes.');
        return null;
      }
      final rows = jsonDecode(utf8.decode(response.bodyBytes));
      if (rows is! List) throw const FormatException('Respuesta inválida');
      return [
        for (final row in rows)
          if (row is Map)
            ?SubscriptionPlanOption.tryFromJson(Map<String, dynamic>.from(row)),
      ];
    } on FormatException {
      debugPrint('El JSON de planes está malformado.');
    } catch (error) {
      debugPrint('No fue posible consultar los planes: $error');
    }
    return null;
  }

  /// Descarga todos los indicativos registrados en Supabase (activos e
  /// inactivos) y reemplaza la caché. Devuelve `false` si no pudo sincronizar.
  Future<bool> _syncCountryCodes() async {
    final base = Uri.tryParse(_supabaseUrl.trim());
    if (base == null || base.scheme != 'https' || base.host.isEmpty) {
      debugPrint('Supabase no configurado: se usan los indicativos locales.');
      return false;
    }

    // Filtros codificados por `Uri`, sin concatenar datos del usuario.
    final uri = base.replace(
      path: '/rest/v1/$_table',
      queryParameters: {'select': _columns, 'order': 'country_name.asc'},
    );

    late final http.Response response;
    try {
      response = await _get(
        uri,
        headers: {'apikey': _publishableKey, 'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 15));
    } catch (error) {
      debugPrint('Sin conexión: se usa la caché de indicativos ($error).');
      return false;
    }

    if (response.statusCode != 200) {
      debugPrint('Supabase respondió ${response.statusCode} a indicativos.');
      return false;
    }

    try {
      // UTF-8 explícito para no dañar tildes (México, Perú, Panamá).
      final rows = jsonDecode(utf8.decode(response.bodyBytes));
      if (rows is! List) throw const FormatException('Respuesta inválida');
      final entries = rows
          .map(
            (row) => PhoneCountryCode.fromJson(
              Map<String, dynamic>.from(row as Map),
            ),
          )
          .toList(growable: false);

      final dao = await _dao();
      await _saveLengths(rows);
      // Se reemplaza completa (lo que ya no está en Supabase desaparece) en
      // una transacción, para no dejar la caché vacía si la inserción falla.
      await dao.replaceAll(entries);
      await _preferences.saveCatalogsSyncedAt(_clock());
      return true;
    } on FormatException {
      debugPrint('El JSON de indicativos está malformado.');
    } on TypeError {
      debugPrint('Los tipos de indicativos no coinciden con el modelo.');
    } catch (error) {
      debugPrint('No fue posible guardar los indicativos: $error');
    }
    return false;
  }

  /// Guarda la longitud del celular de las filas que la traen.
  Future<void> _saveLengths(List<dynamic> rows) async {
    final lengths = <int, ({int min, int max})>{};
    for (final row in rows) {
      if (row is! Map) continue;
      final id = row['id'];
      final min = row['phone_min_length'];
      final max = row['phone_max_length'];
      if (id is int && min is int && max is int) {
        lengths[id] = (min: min, max: max);
      }
    }
    try {
      await _preferences.savePhoneLengths(lengths);
    } catch (error) {
      debugPrint('No fue posible guardar la longitud de celulares: $error');
    }
  }

  Future<List<CountryPhoneCode>> _readActive() async {
    try {
      final entries = await (await _dao()).findActive();
      Map<int, ({int min, int max})> lengths = const {};
      try {
        lengths = await _preferences.loadPhoneLengths();
      } catch (_) {}
      return entries
          .map(
            (entry) => CountryPhoneCode.fromEntry(
              entry,
              phoneMinLength: lengths[entry.id]?.min,
              phoneMaxLength: lengths[entry.id]?.max,
            ),
          )
          .where((code) => code.isoCode.isNotEmpty)
          .toList(growable: false)
        ..sort(
          (a, b) => a.countryName.toLowerCase().compareTo(
            b.countryName.toLowerCase(),
          ),
        );
    } catch (error) {
      debugPrint('No fue posible leer la caché de indicativos: $error');
      return const [];
    }
  }

  Future<bool> _isCacheFresh() async {
    try {
      final syncedAt = await _preferences.loadCatalogsSyncedAt();
      return syncedAt != null && _clock().difference(syncedAt) < cacheTtl;
    } catch (_) {
      return false;
    }
  }
}
