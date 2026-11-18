import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:machuco/database/app_database.dart';
import 'package:machuco/database/repository/auth/auth_catalog_repository.dart';
import 'package:machuco/service/auth/auth_preferences.dart';
import 'package:machuco/service/storage/shared_preferences_local_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _documentTypesBody = '''
[
  {"id":1,"code":"CC","name":"Cédula de ciudadanía","pattern":"^\\\\d{6,10}\$","example":"1020304050","sort_order":1},
  {"id":2,"code":"CE","name":"Cédula de extranjería","pattern":"^\\\\d{6,12}\$","example":"345678","sort_order":2},
  {"id":3,"code":"NIT","name":"NIT","pattern":"^x\$","example":"1","sort_order":3},
  {"id":4,"code":"XX","name":"Desconocido","pattern":"^x\$","example":"1","sort_order":4},
  {"id":5,"code":"PAS","name":null,"pattern":"^x\$","example":"1","sort_order":5}
]
''';

void main() {
  late AppDatabase database;
  late AuthPreferences preferences;
  late Directory directory;
  final now = DateTime.utc(2026, 11, 17, 12);

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = AuthPreferences(
      preferences: SharedPreferencesLocalService(namespace: 'auth'),
    );
    directory = await Directory.systemTemp.createTemp('machuco_doc_types_');
    database = await AppDatabaseProvider.open(
      name: '${directory.path}${Platform.pathSeparator}auth.db',
    );
  });

  tearDown(() async {
    await database.close();
    await directory.delete(recursive: true);
  });

  AuthCatalogRepository build(http.Client client) => AuthCatalogRepository(
    database: database,
    httpClient: client,
    supabaseUrl: 'https://example.supabase.co',
    publishableKey: 'public-key',
    preferences: preferences,
    clock: () => now,
  );

  group('longitud del celular por país', () {
    test('usa phone_min_length y phone_max_length si el maestro los trae y '
        'los conserva sin red', () async {
      final client = MockClient(
        (_) async => http.Response.bytes(
          utf8.encode(
            '[{"id":1,"country_code":"CO","country_name":"Colombia",'
            '"calling_code":"+57","active":true,'
            '"phone_min_length":10,"phone_max_length":10},'
            '{"id":3,"country_code":"MX","country_name":"México",'
            '"calling_code":"+52","active":true}]',
          ),
          200,
        ),
      );

      final result = await build(client).getCountryPhoneCodes();
      final co = result.firstWhere((code) => code.isoCode == 'CO');
      final mx = result.firstWhere((code) => code.isoCode == 'MX');
      expect(co.phoneMinLength, 10);
      expect(co.phoneMaxLength, 10);
      // Sin las columnas se mantiene el rango de 7 a 15 dígitos.
      expect(mx.phoneMinLength, 7);
      expect(mx.phoneMaxLength, 15);

      // Con la caché vigente (sin red) siguen aplicándose.
      final offline = await build(
        MockClient((_) async => fail('No debe llamar a la red')),
      ).getCountryPhoneCodes();
      expect(
        offline.firstWhere((code) => code.isoCode == 'CO').phoneMaxLength,
        10,
      );
    });

    test('ignora longitudes incoherentes', () async {
      final client = MockClient(
        (_) async => http.Response.bytes(
          utf8.encode(
            '[{"id":1,"country_code":"CO","country_name":"Colombia",'
            '"calling_code":"+57","active":true,'
            '"phone_min_length":12,"phone_max_length":8}]',
          ),
          200,
        ),
      );

      final result = await build(client).getCountryPhoneCodes();

      expect(result.single.phoneMinLength, 7);
      expect(result.single.phoneMaxLength, 15);
    });
  });

  group('tipos de documento', () {
    test('consulta document_types activos y ofrece solo CC, CE y '
        'pasaporte', () async {
      late Uri requested;
      final client = MockClient((request) async {
        requested = request.url;
        return http.Response.bytes(utf8.encode(_documentTypesBody), 200);
      });

      final result = await build(client).getDocumentTypes();

      expect(requested.path, '/rest/v1/document_types');
      expect(requested.queryParameters, {
        'select': 'id,code,name,pattern,example,sort_order',
        'is_active': 'eq.true',
        'order': 'sort_order.asc',
      });
      expect(result.map((type) => type.code), ['CC', 'CE']);
      expect(result.first.example, '1020304050');
      // Se guardó en la tabla document_types que ya existe en AppDatabase.
      final stored = await database.documentTypeDao.findActive();
      expect(stored.map((entry) => entry.code), contains('CC'));
    });

    test('usa la caché en memoria hasta forceRefresh', () async {
      var calls = 0;
      final client = MockClient((_) async {
        calls++;
        return http.Response.bytes(utf8.encode(_documentTypesBody), 200);
      });
      final repository = build(client);

      await repository.getDocumentTypes();
      await repository.getDocumentTypes();
      expect(calls, 1);
      await repository.getDocumentTypes(forceRefresh: true);
      expect(calls, 2);
    });

    test('sin red cae a la tabla local; si está vacía lanza', () async {
      final offline = await build(
        MockClient((_) async => http.Response('boom', 500)),
      ).getDocumentTypes();
      expect(offline, isNotEmpty);

      await database.documentTypeDao.deleteAll();
      await expectLater(
        build(
          MockClient((_) async => http.Response('boom', 500)),
        ).getDocumentTypes(),
        throwsA(isA<AuthCatalogRepositoryException>()),
      );
    });
  });
}
