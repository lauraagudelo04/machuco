import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:machuco/database/app_database.dart';
import 'package:machuco/database/repository/document_type/document_type_repository.dart';
import 'package:machuco/models/owner_management/document_type.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _supabaseBody = '''
[
  {"id":1,"code":"CC","name":"Cédula de ciudadanía",
   "pattern":"^\\\\d{6,10}\$","example":"1020304050","is_active":true,"sort_order":1},
  {"id":3,"code":"NIT","name":"Número de identificación tributaria",
   "pattern":"^\\\\d{9,10}(-\\\\d)?\$","example":"900123456-7","is_active":true,"sort_order":3},
  {"id":5,"code":"TI","name":"Tarjeta de identidad",
   "pattern":"^\\\\d{6,11}\$","example":"1020304050","is_active":false,"sort_order":5},
  {"id":9,"code":"ZZ","name":"Tipo retirado del dominio",
   "pattern":"^.*\$","example":"x","is_active":true,"sort_order":9}
]
''';

void main() {
  late AppDatabase database;
  late Directory directory;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('machuco_doc_types_');
    database = await AppDatabaseProvider.open(
      name: '${directory.path}${Platform.pathSeparator}document_types.db',
    );
  });

  tearDown(() async {
    await database.close();
    await directory.delete(recursive: true);
  });

  DocumentTypeRepository buildRepository(
    http.Client client, {
    String baseUrl = 'https://example.supabase.co',
  }) => DocumentTypeRepository(
    database: database,
    httpClient: client,
    supabaseUrl: baseUrl,
    apiKey: 'public-key',
  );

  test('sin refresco responde con la caché y no llama a la red', () async {
    final client = MockClient((_) async => fail('No debe llamar a la red'));

    final types = await buildRepository(client).getActiveDocumentTypes();

    expect(types.map((type) => type.code), ['CC', 'CE', 'NIT', 'PAS', 'TI']);
  });

  test('el refresco consulta Supabase, filtra y reemplaza la caché', () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/rest/v1/document_types');
      expect(request.url.queryParameters['is_active'], 'eq.true');
      expect(request.url.queryParameters['order'], 'sort_order.asc');
      expect(request.headers['apikey'], 'public-key');
      return http.Response.bytes(utf8.encode(_supabaseBody), 200);
    });

    final types = await buildRepository(
      client,
    ).getActiveDocumentTypes(forceRefresh: true);

    // TI viene inactivo y ZZ no existe en el enum: ambos se descartan.
    expect(types, [DocumentType.citizenshipCard, DocumentType.taxId]);
    expect(
      (await database.documentTypeDao.findAll()).map((entry) => entry.code),
      ['CC', 'NIT'],
    );
  });

  test('si Supabase falla, el refresco conserva la caché', () async {
    final client = MockClient((_) async => http.Response('error', 500));

    final types = await buildRepository(
      client,
    ).getActiveDocumentTypes(forceRefresh: true);

    expect(types.map((type) => type.code), ['CC', 'CE', 'NIT', 'PAS', 'TI']);
  });

  test('lanza un error si falla el refresco y no hay caché', () async {
    await database.documentTypeDao.deleteAll();
    final client = MockClient((_) async => throw const SocketException('x'));

    expect(
      buildRepository(client).getActiveDocumentTypes(forceRefresh: true),
      throwsA(isA<DocumentTypeRepositoryException>()),
    );
  });

  test('sin Supabase configurado devuelve la caché local', () async {
    final client = MockClient((_) async => fail('No debe llamar a la red'));

    final types = await buildRepository(
      client,
      baseUrl: '',
    ).getActiveDocumentTypes(forceRefresh: true);

    expect(types.map((type) => type.code), ['CC', 'CE', 'NIT', 'PAS', 'TI']);
  });
}
