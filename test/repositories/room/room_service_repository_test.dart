import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:machuco/database/app_database.dart';
import 'package:machuco/models/room/room_service.dart';
import 'package:machuco/repositories/room/room_dao.dart';
import 'package:machuco/repositories/room/room_service_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late AppDatabase database;
  late RoomDao dao;

  setUpAll(sqfliteFfiInit);

  setUp(() {
    database = AppDatabase(
      factory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    );
    dao = database.roomDao;
  });

  tearDown(() => database.close());

  test('consulta Supabase y guarda el resultado localmente', () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/rest/v1/room_included_services');
      expect(request.url.queryParameters['select'], 'id,name');
      expect(request.headers['apikey'], 'public-key');
      return http.Response(
        '[{"id":1,"name":"Jacuzzi"},{"id":2,"name":"Luces"}]',
        200,
      );
    });
    final repository = RoomServiceRepository(
      baseUrl: 'https://example.supabase.co',
      apiKey: 'public-key',
      roomDao: dao,
      httpClient: client,
    );

    final result = await repository.getIncludedServices();

    expect(result, hasLength(2));
    expect((await dao.getIncludedServices()).last.name, 'Luces');
  });

  test('usa el cache cuando Supabase falla', () async {
    await dao.saveIncludedServices(const [RoomService(id: 4, name: 'Fogata')]);
    final repository = RoomServiceRepository(
      baseUrl: 'https://example.supabase.co',
      apiKey: 'public-key',
      roomDao: dao,
      httpClient: MockClient((_) async => http.Response('error', 500)),
    );

    final result = await repository.getIncludedServices(forceRefresh: true);

    expect(result.single.name, 'Fogata');
  });
}
