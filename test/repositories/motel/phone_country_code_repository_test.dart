import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:machuco/database/app_database.dart';
import 'package:machuco/database/repository/motel/phone_country_code_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Respuesta con el mismo formato que devuelve Supabase.
const _colombiaJson =
    '[{"id":1,"country_code":"CO","country_name":"Colombia",'
    '"calling_code":"+57","active":true}]';

class _FakeHttpClient extends http.BaseClient {
  _FakeHttpClient(this.response, {this.statusCode = 200});

  final String response;
  final int statusCode;
  int calls = 0;
  Uri? lastUrl;
  Map<String, String>? lastHeaders;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    calls++;
    lastUrl = request.url;
    lastHeaders = request.headers;
    return http.StreamedResponse(
      Stream.value(response.codeUnits),
      statusCode,
    );
  }
}

void main() {
  late AppDatabase database;
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
  });

  tearDown(() async {
    await database.close();
    await directory.delete(recursive: true);
  });

  PhoneCountryCodeRepository repositoryWith(http.Client client) =>
      PhoneCountryCodeRepository(
        baseUrl: 'https://ogrbbuwtsyezegkpwtsl.supabase.co',
        apiKey: 'test-api-key',
        daoProvider: () async => database.phoneCountryCodeDao,
        httpClient: client,
      );

  test('consulta el maestro remoto y lo cachea', () async {
    final repository = repositoryWith(_FakeHttpClient(_colombiaJson));

    final countryCodes = await repository.getCountryCodes();

    expect(countryCodes, hasLength(1));
    expect(countryCodes.single.countryName, 'Colombia');
    expect(countryCodes.single.callingCode, '+57');
    expect(await database.phoneCountryCodeDao.findActive(), hasLength(1));
  });

  test('envía la apikey y filtra solo los activos', () async {
    final client = _FakeHttpClient(_colombiaJson);

    await repositoryWith(client).getCountryCodes();

    expect(client.lastHeaders?['apikey'], 'test-api-key');
    expect(client.lastUrl?.path, '/rest/v1/phone_country_codes');
    expect(client.lastUrl?.queryParameters['active'], 'eq.true');
  });

  test('usa la caché sin consultar el maestro remoto', () async {
    final client = _FakeHttpClient(_colombiaJson);
    final repository = repositoryWith(client);

    await repository.getCountryCodes();
    await repository.getCountryCodes();

    expect(client.calls, 1);
  });

  test('recurre a la caché cuando Supabase falla', () async {
    await repositoryWith(_FakeHttpClient(_colombiaJson)).getCountryCodes();

    final countryCodes = await repositoryWith(
      _FakeHttpClient('{"message":"boom"}', statusCode: 500),
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