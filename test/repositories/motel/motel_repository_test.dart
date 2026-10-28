import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:machuco/database/app_database.dart';
import 'package:machuco/database/repository/motel/motel_dao.dart';
import 'package:machuco/database/repository/motel/motel_repository.dart';
import 'package:machuco/models/motel/motel_model.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _FakeHttpClient extends http.BaseClient {
  _FakeHttpClient(this.response, {this.statusCode = 200});

  final String response;
  final int statusCode;
  int calls = 0;
  String? lastMethod;
  Map<String, String>? lastHeaders;
  String? lastBody;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    calls++;
    lastMethod = request.method;
    lastHeaders = request.headers;
    if (request is http.Request) {
      lastBody = request.body;
    }
    return http.StreamedResponse(
      Stream.value(response.codeUnits),
      statusCode,
    );
  }
}

void main() {
  late AppDatabase database;
  late MotelDao dao;
  late Directory directory;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('machuco_motel_repo_');
    database = await AppDatabaseProvider.open(
      name: '${directory.path}${Platform.pathSeparator}motels.db',
    );
    dao = database.motelDao;
  });

  tearDown(() async {
    await database.close();
    await directory.delete(recursive: true);
  });

  MotelRepository repositoryWith(http.Client client) => MotelRepository(
        baseUrl: 'https://ogrbbuwtsyezegkpwtsl.supabase.co',
        apiKey: 'test-api-key',
        daoProvider: () async => dao,
        httpClient: client,
      );

  test('consulta el maestro remoto y lo cachea', () async {
    final client = _FakeHttpClient(
      '[{"id":"1","owner_id":"owner-1","name":"Motel Test","email":"t@t.com","room_count":5,"nit":"900123456-1","address":"Calle 1","phone":"+573001234567","description":null,"general_location":"Centro","payment_methods":["Efectivo"],"image_urls":[],"is_available":true}]',
    );
    final repository = repositoryWith(client);

    final motels = await repository.getMotels();

    expect(motels, hasLength(1));
    expect(motels.single.name, 'Motel Test');
    expect(await dao.findAll(), hasLength(1));
    expect(client.lastHeaders?['apikey'], 'test-api-key');
  });

  test('usa la caché cuando falla la red', () async {
    await repositoryWith(
      _FakeHttpClient(
        '[{"id":"1","owner_id":"owner-1","name":"Motel Test","email":"t@t.com","room_count":5,"nit":"900123456-1","address":"Calle 1","phone":"+573001234567","description":null,"general_location":"Centro","payment_methods":["Efectivo"],"image_urls":[],"is_available":true}]',
      ),
    ).getMotels();

    final failingClient = _FakeHttpClient('{"message":"boom"}', statusCode: 500);
    final motels = await repositoryWith(failingClient).getMotels();

    expect(motels.single.name, 'Motel Test');
  });

  test('lanza excepción cuando no hay red ni caché', () async {
    final repository = repositoryWith(
      _FakeHttpClient('{"message":"boom"}', statusCode: 500),
    );

    expect(
      () => repository.getMotels(),
      throwsA(isA<MotelRepositoryException>()),
    );
  });

  test('addMotel envía apikey y cuerpo correcto con Prefer', () async {
    final client = _FakeHttpClient(
      '[{"id":"9","owner_id":"owner-1","name":"Motel Nuevo","email":"n@t.com","room_count":3,"nit":"900123456-9","address":"Calle 9","phone":"+573009999999","description":null,"general_location":null,"payment_methods":["Efectivo"],"image_urls":[],"is_available":true}]',
    );
    final repository = repositoryWith(client);

    const motel = Motel(
      id: '9',
      ownerId: 'owner-1',
      name: 'Motel Nuevo',
      email: 'n@t.com',
      roomCount: 3,
      nit: '900123456-9',
      address: 'Calle 9',
      phone: '+573009999999',
      paymentMethods: ['Efectivo'],
      imageUrls: [],
      isAvailable: true,
    );

    final result = await repository.addMotel(motel);

    expect(client.lastMethod, 'POST');
    expect(client.lastHeaders?['apikey'], 'test-api-key');
    expect(client.lastHeaders?['Prefer'], 'return=representation');
    expect(client.lastBody, isNotNull);
    expect(result.id, '9');
  });

  test('updateMotel lanza excepción si no hay representación', () async {
    final client = _FakeHttpClient('[]');
    final repository = repositoryWith(client);

    const motel = Motel(
      id: '9',
      ownerId: 'owner-1',
      name: 'Motel Nuevo',
      email: 'n@t.com',
      roomCount: 3,
      nit: '900123456-9',
      address: 'Calle 9',
      phone: '+573009999999',
      paymentMethods: ['Efectivo'],
      imageUrls: [],
      isAvailable: true,
    );

    expect(
      () => repository.updateMotel(motel),
      throwsA(isA<MotelRepositoryException>()),
    );
  });

  test('updateMotel envía PATCH con Prefer', () async {
    final client = _FakeHttpClient(
      '[{"id":"9","owner_id":"owner-1","name":"Motel Nuevo","email":"n@t.com","room_count":3,"nit":"900123456-9","address":"Calle 9","phone":"+573009999999","description":null,"general_location":null,"payment_methods":["Efectivo"],"image_urls":[],"is_available":true}]',
    );
    final repository = repositoryWith(client);

    const motel = Motel(
      id: '9',
      ownerId: 'owner-1',
      name: 'Motel Nuevo',
      email: 'n@t.com',
      roomCount: 3,
      nit: '900123456-9',
      address: 'Calle 9',
      phone: '+573009999999',
      paymentMethods: ['Efectivo'],
      imageUrls: [],
      isAvailable: true,
    );

    await repository.updateMotel(motel);
    expect(client.lastMethod, 'PATCH');
    expect(client.lastHeaders?['Prefer'], 'return=representation');
  });

  test('setAvailability actualiza solo is_available', () async {
    final client = _FakeHttpClient(
      '[{"id":"1","owner_id":"owner-1","name":"Motel Test","email":"t@t.com","room_count":5,"nit":"900123456-1","address":"Calle 1","phone":"+573001234567","description":null,"general_location":"Centro","payment_methods":["Efectivo"],"image_urls":[],"is_available":false}]',
    );
    final repository = repositoryWith(client);

    await repository.setAvailability('1', false);
    expect(client.lastMethod, 'PATCH');
    expect(client.lastBody, contains('is_available'));
  });

  test('lanza mensaje claro si NIT duplicado', () async {
    final client = _FakeHttpClient('{"message":"duplicate"}', statusCode: 409);
    final repository = repositoryWith(client);

    const motel = Motel(
      id: '9',
      ownerId: 'owner-1',
      name: 'Motel Nuevo',
      email: 'n@t.com',
      roomCount: 3,
      nit: '900123456-9',
      address: 'Calle 9',
      phone: '+573009999999',
      paymentMethods: ['Efectivo'],
      imageUrls: [],
      isAvailable: true,
    );

    expect(
      () => repository.addMotel(motel),
      throwsA(
        predicate((e) => e.toString().contains('Ya existe un motel con ese NIT')),
      ),
    );
  });
}
