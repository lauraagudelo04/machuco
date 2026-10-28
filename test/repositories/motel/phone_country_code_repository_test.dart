import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:machuco/database/app_database.dart';
import 'package:machuco/database/repository/motel/phone_country_code_dao.dart';
import 'package:machuco/database/repository/motel/phone_country_code_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _FakeHttpClient extends http.BaseClient {
  _FakeHttpClient(this.response, {this.statusCode = 200});

  final String response;
  final int statusCode;
  int calls = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    calls++;
    return http.StreamedResponse(
      Stream.value(response.codeUnits),
      statusCode,
    );
  }
}

void main() {
  late AppDatabase database;
  late PhoneCountryCodeDao dao;
  late Directory directory;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('machuco_country_repo_');
    database = await AppDatabaseProvider.open(
      name: '${directory.path}${Platform.pathSeparator}country_repo.db',
    );
    dao = database.phoneCountryCodeDao;
  });

  tearDown(() async {
    await database.close();
    await directory.delete(recursive: true);
  });

  PhoneCountryCodeRepository repositoryWith(http.Client client) =>
      PhoneCountryCodeRepository(
        baseUrl: 'https://ogrbbuwtsyezegkpwtsl.supabase.co',
        apiKey: 'test-api-key',
        countryCodeDao: dao,
        httpClient: client,
      );

  test('consulta el maestro remoto y lo cachea', () async {
    final client = _FakeHttpClient(
      '[{"id":1,"country_code":"CO","country_name":"Colombia","calling_code":"+57","active":true}]',
    );
    final repository = repositoryWith(client);

    final countryCodes = await repository.getCountryCodes();

    expect(countryCodes, hasLength(1));
    expect(countryCodes.single.countryName, 'Colombia');
    expect(await dao.getCountryCodes(), hasLength(1));
  });

  test('usa la caché sin consultar el maestro remoto', () async {
    final client = _FakeHttpClient(
      '[{"id":1,"country_code":"CO","country_name":"Colombia","calling_code":"+57","active":true}]',
    );
    final repository = repositoryWith(client);

    await repository.getCountryCodes();
    await repository.getCountryCodes();

    expect(client.calls, 1);
  });

  test('recurre a la caché cuando Supabase falla', () async {
    await repositoryWith(
      _FakeHttpClient(
        '[{"id":1,"country_code":"CO","country_name":"Colombia","calling_code":"+57","active":true}]',
      ),
    ).getCountryCodes();

    final failingClient = _FakeHttpClient('{"message":"boom"}', statusCode: 500);
    final countryCodes = await repositoryWith(
      failingClient,
    ).getCountryCodes(forceRefresh: true);

    expect(countryCodes.single.countryName, 'Colombia');
  });

  test('lanza excepción cuando no hay red ni caché', () async {
    final repository = repositoryWith(
      _FakeHttpClient('{"message":"boom"}', statusCode: 500),
    );

    expect(
      () => repository.getCountryCodes(),
      throwsA(isA<PhoneCountryCodeRepositoryException>()),
    );
  });
}
