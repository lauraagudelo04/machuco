import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:machuco/database/app_database.dart';
import 'package:machuco/database/repository/auth/auth_catalog_dao.dart';
import 'package:machuco/database/repository/auth/auth_catalog_repository.dart';
import 'package:machuco/models/auth/country_phone_code.dart';
import 'package:machuco/service/auth/auth_preferences.dart';
import 'package:machuco/service/storage/shared_preferences_local_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _supabaseBody = '''
[
  {"id":2,"iso_code":"MX","country_name":"México","dial_code":"+52","flag_emoji":null,
   "phone_min_length":10,"phone_max_length":10,"is_active":true,"sort_order":2},
  {"id":1,"iso_code":"CO","country_name":"Colombia","dial_code":"+57","flag_emoji":"🇨🇴",
   "phone_min_length":10,"phone_max_length":10,"is_active":true,"sort_order":1}
]
''';

const _cachedArgentina = CountryPhoneCode(
  id: 7,
  isoCode: 'AR',
  countryName: 'Argentina',
  dialCode: '+54',
  phoneMinLength: 10,
  phoneMaxLength: 11,
  sortOrder: 3,
);

void main() {
  late AppDatabase database;
  late AuthCatalogDao dao;
  late AuthPreferences preferences;
  late Directory directory;
  final now = DateTime.utc(2026, 10, 20, 12);

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
    dao = database.authCatalogDao;
  });

  tearDown(() async {
    await database.close();
    await directory.delete(recursive: true);
  });

  AuthCatalogRepository buildRepository(
    http.Client client, {
    String baseUrl = 'https://example.supabase.co',
  }) => AuthCatalogRepository(
    baseUrl: baseUrl,
    apiKey: 'public-key',
    catalogDao: dao,
    preferences: preferences,
    httpClient: client,
    clock: () => now,
  );

  test('consulta Supabase, ordena por sort_order y guarda en SQLite', () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/rest/v1/country_phone_codes');
      expect(request.url.queryParameters['is_active'], 'eq.true');
      expect(request.url.queryParameters['order'], 'sort_order.asc');
      expect(request.headers['apikey'], 'public-key');
      return http.Response.bytes(utf8.encode(_supabaseBody), 200);
    });

    final result = await buildRepository(client).getCountryPhoneCodes();

    expect(result.map((code) => code.isoCode), ['CO', 'MX']);
    expect(result.first.flagEmoji, '🇨🇴');
    expect(result.last.countryName, 'México');
    expect(
      (await dao.getActiveCountryPhoneCodes()).map((code) => code.isoCode),
      ['CO', 'MX'],
    );
    expect(await preferences.loadCatalogsSyncedAt(), now);
  });

  test('usa la caché vigente sin consultar la red', () async {
    await dao.replaceCountryPhoneCodes(const [_cachedArgentina]);
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

  test('refresca cuando la caché supera las 24 horas', () async {
    await dao.replaceCountryPhoneCodes(const [_cachedArgentina]);
    await preferences.saveCatalogsSyncedAt(
      now.subtract(const Duration(hours: 25)),
    );
    final client = MockClient(
      (_) async => http.Response.bytes(utf8.encode(_supabaseBody), 200),
    );

    final result = await buildRepository(client).getCountryPhoneCodes();

    expect(result.map((code) => code.isoCode), ['CO', 'MX']);
    expect(
      (await dao.getActiveCountryPhoneCodes()).any(
        (code) => code.isoCode == 'AR',
      ),
      isFalse,
    );
  });

  test('usa la caché cuando Supabase falla', () async {
    await dao.replaceCountryPhoneCodes(const [_cachedArgentina]);
    final client = MockClient((_) async => http.Response('error', 500));

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

  test(
    'usa la semilla de desarrollo si Supabase no está configurado',
    () async {
      final client = MockClient((_) async => fail('No debe llamar a la red'));

      final result = await buildRepository(
        client,
        baseUrl: '',
      ).getCountryPhoneCodes();

      expect(result.single.isDevelopmentSeed, isTrue);
      expect(result.single.dialCode, '+57');
    },
  );
}
