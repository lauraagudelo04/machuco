import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:machuco/database/app_database.dart';
import 'package:machuco/database/model/phone_country_code/phone_country_code.dart';
import 'package:machuco/database/repository/auth/auth_catalog_repository.dart';
import 'package:machuco/service/auth/auth_preferences.dart';
import 'package:machuco/service/storage/shared_preferences_local_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Mismo formato que devuelve la tabla `phone_country_codes` de Supabase.
const _supabaseBody = '''
[
  {"id":3,"country_code":"MX","country_name":"México","calling_code":"+52","active":true},
  {"id":1,"country_code":"CO","country_name":"Colombia","calling_code":"+57","active":true},
  {"id":9,"country_code":"EC","country_name":"Ecuador","calling_code":"+593","active":false}
]
''';

const _cachedArgentina = PhoneCountryCode(
  id: 5,
  countryCode: 'AR',
  countryName: 'Argentina',
  callingCode: '+54',
  active: true,
);

void main() {
  late AppDatabase database;
  late AuthPreferences preferences;
  late Directory directory;
  final now = DateTime.utc(2026, 11, 4, 12);

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = AuthPreferences(
      preferences: SharedPreferencesLocalService(namespace: 'auth'),
    );
    directory = await Directory.systemTemp.createTemp('machuco_auth_catalog_');
    database = await AppDatabaseProvider.open(
      name: '${directory.path}${Platform.pathSeparator}auth.db',
    );
  });

  tearDown(() async {
    await database.close();
    await directory.delete(recursive: true);
  });

  AuthCatalogRepository buildRepository(
    http.Client client, {
    String supabaseUrl = 'https://example.supabase.co',
  }) => AuthCatalogRepository(
    database: database,
    httpClient: client,
    supabaseUrl: supabaseUrl,
    publishableKey: 'public-key',
    preferences: preferences,
    clock: () => now,
  );

  test('consulta phone_country_codes, guarda todo en SQLite y muestra los '
      'activos ordenados por nombre', () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/rest/v1/phone_country_codes');
      expect(
        request.url.queryParameters['select'],
        'id,country_code,country_name,calling_code,active',
      );
      expect(request.headers['apikey'], 'public-key');
      return http.Response.bytes(utf8.encode(_supabaseBody), 200);
    });

    final result = await buildRepository(client).getCountryPhoneCodes();

    expect(result.map((code) => code.isoCode), ['CO', 'MX']);
    expect(result.last.countryName, 'México');
    expect(result.first.dialCode, '+57');
    final stored = await database.phoneCountryCodeDao.findAll();
    expect(stored, hasLength(3), reason: 'el inactivo también se cachea');
    expect(await preferences.loadCatalogsSyncedAt(), now);
  });

  test('usa la caché vigente sin consultar la red', () async {
    await database.phoneCountryCodeDao.insertCountryCodes([_cachedArgentina]);
    await preferences.saveCatalogsSyncedAt(
      now.subtract(const Duration(hours: 1)),
    );
    var calls = 0;
    final client = MockClient((_) async {
      calls++;
      return http.Response('[]', 200);
    });

    final result = await buildRepository(client).getCountryPhoneCodes();

    expect(calls, 0);
    expect(result.single.isoCode, 'AR');
  });

  test('refresca cuando la caché supera las 24 horas y elimina lo que ya '
      'no está en Supabase', () async {
    await database.phoneCountryCodeDao.insertCountryCodes([_cachedArgentina]);
    await preferences.saveCatalogsSyncedAt(
      now.subtract(const Duration(hours: 25)),
    );
    final client = MockClient(
      (_) async => http.Response.bytes(utf8.encode(_supabaseBody), 200),
    );

    final result = await buildRepository(client).getCountryPhoneCodes();

    expect(result.map((code) => code.isoCode), ['CO', 'MX']);
  });

  test('usa la caché cuando Supabase falla', () async {
    await database.phoneCountryCodeDao.insertCountryCodes([_cachedArgentina]);
    final client = MockClient((_) async => http.Response('error', 500));

    final result = await buildRepository(
      client,
    ).getCountryPhoneCodes(forceRefresh: true);

    expect(result.single.isoCode, 'AR');
  });

  test('usa la caché cuando el JSON está malformado', () async {
    await database.phoneCountryCodeDao.insertCountryCodes([_cachedArgentina]);
    final client = MockClient(
      (_) async => http.Response('{"no":"lista"}', 200),
    );

    final result = await buildRepository(
      client,
    ).getCountryPhoneCodes(forceRefresh: true);

    expect(result.single.isoCode, 'AR');
  });

  test('lanza un error sin conexión y sin caché', () async {
    final client = MockClient((_) async => throw const SocketException('x'));

    expect(
      buildRepository(client).getCountryPhoneCodes(),
      throwsA(isA<AuthCatalogRepositoryException>()),
    );
  });

  test('lanza un error si Supabase no tiene indicativos activos', () async {
    final client = MockClient((_) async => http.Response('[]', 200));

    expect(
      buildRepository(client).getCountryPhoneCodes(),
      throwsA(isA<AuthCatalogRepositoryException>()),
    );
  });

  test(
    'usa la semilla de desarrollo si Supabase no está configurado',
    () async {
      final client = MockClient((_) async => fail('No debe llamar a la red'));

      final result = await buildRepository(
        client,
        supabaseUrl: '',
      ).getCountryPhoneCodes();

      expect(result.single.isDevelopmentSeed, isTrue);
      expect(result.single.dialCode, '+57');
    },
  );
}
