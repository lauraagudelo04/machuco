import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:machuco/database/app_database.dart';
import 'package:machuco/database/repository/room/room_sync_repository.dart';
import 'package:machuco/models/room/room_models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class MemoryRemote implements RoomRemoteStore {
  bool fail = false;
  final documents = <String, Map<String, Map<String, dynamic>>>{};
  final writes = <String>[];

  @override
  Future<void> write(
    String collection,
    String id,
    Map<String, dynamic> data,
  ) async {
    if (fail) throw StateError('sin conexión');
    documents.putIfAbsent(collection, () => {})[id] = Map.of(data);
    writes.add('$collection/$id');
  }

  @override
  Future<List<Map<String, dynamic>>> read(String collection) async =>
      documents[collection]?.values
          .map((d) => Map<String, dynamic>.of(d))
          .toList() ??
      [];
}

void main() {
  late AppDatabase database;
  late Directory directory;
  late MemoryRemote remote;
  String? uid;
  RoomSyncRepository repository({String? motel = 'm1', String? owner = 'u1'}) =>
      RoomSyncRepository(
        dao: database.roomDao,
        remote: remote,
        currentUserId: () => uid,
        motelId: motel,
        ownerId: owner,
      );
  const type = RoomTypeData(id: 't1', motelId: 'm1', name: 'Suite');
  const room = RoomVisualData(
    id: 'r1',
    motelId: 'm1',
    name: 'Suite',
    description: '',
    idType: 't1',
    pricePerHour: 50000,
    roomNumber: '101',
    capacity: 2,
    imageUrls: [],
    isActive: true,
    includedServices: [],
  );

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('machuco_room_sync_');
    database = await AppDatabaseProvider.open(
      name: '${directory.path}/rooms.db',
    );
    remote = MemoryRemote();
    uid = 'u1';
  });
  tearDown(() async {
    await database.close();
    await directory.delete(recursive: true);
  });

  test(
    'fallo remoto conserva pendientes y un nuevo repositorio los reintenta en orden',
    () async {
      final repo = repository();
      await repo.saveType(type);
      await repo.saveRoom(room);
      remote.fail = true;
      await expectLater(repo.sync(), throwsStateError);
      expect(await database.roomDao.pendingChanges('u1'), hasLength(2));
      expect(await database.roomDao.getRooms(), hasLength(1));
      remote.fail = false;
      await repository().sync();
      expect(remote.writes, ['room_types/t1', 'rooms/r1']);
      expect(await database.roomDao.pendingChanges('u1'), isEmpty);
      await repository().deleteRoom(room);
      await repository().deleteType(type);
      await repository().sync();
      expect(remote.documents['rooms']!['r1']!['deleted'], isTrue);
      expect(remote.documents['room_types']!['t1']!['deleted'], isTrue);
      expect(await database.roomDao.getRooms(), isEmpty);
      expect(await database.roomDao.getRoomTypes(), isEmpty);
    },
  );

  test(
    'cambiar de cuenta no envía pendientes del propietario anterior',
    () async {
      await repository().saveType(type);
      uid = 'u2';
      await repository(motel: null, owner: null).sync();
      expect(remote.writes, isEmpty);
      expect(await database.roomDao.pendingChanges('u1'), hasLength(1));
      await expectLater(repository().saveType(type), throwsStateError);
    },
  );

  test('un cliente descarga el catálogo y los borrados a SQLite', () async {
    remote.documents['room_types'] = {
      't1': {...type.toJson(), 'deleted': false},
    };
    remote.documents['rooms'] = {
      'r1': {...room.toJson(), 'deleted': false},
    };
    final client = repository(motel: null, owner: null);
    await client.sync();
    expect((await database.roomDao.getRooms()).single.id, 'r1');
    remote.documents['rooms']!['r1']!['deleted'] = true;
    remote.documents['room_types']!['t1']!['deleted'] = true;
    await client.sync();
    expect(await database.roomDao.getRooms(), isEmpty);
    expect(await database.roomDao.getRoomTypes(), isEmpty);
    expect(remote.writes, isEmpty);
  });

  test(
    'importa SQLite existente sin resucitar documentos eliminados remotamente',
    () async {
      await database.roomDao.upsertRoomType(type);
      await database.roomDao.upsertRoom(room);
      final repo = repository();
      await repo.sync();
      expect(await database.roomDao.pendingChanges('u1'), hasLength(2));
      await repo.sync();
      expect(remote.writes, ['room_types/t1', 'rooms/r1']);
      remote.documents['rooms']!['r1']!['deleted'] = true;
      remote.documents['room_types']!['t1']!['deleted'] = true;
      await repo.sync();
      expect(await database.roomDao.getRooms(), isEmpty);
      expect(await database.roomDao.pendingChanges('u1'), isEmpty);
    },
  );
}
