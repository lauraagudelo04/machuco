import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:machuco/database/app_database.dart';
import 'package:machuco/models/room/room_models.dart';
import 'package:machuco/models/room/room_service.dart';
import 'package:machuco/database/repository/room/room_dao.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late AppDatabase database;
  late RoomDao dao;
  late Directory directory;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('machuco_room_dao_');
    database = await AppDatabaseProvider.open(
      name: '${directory.path}${Platform.pathSeparator}rooms.db',
    );
    dao = database.roomDao;
  });

  tearDown(() async {
    await database.close();
    await directory.delete(recursive: true);
  });

  test('persiste y recupera habitaciones', () async {
    const room = RoomVisualData(
      id: 'room-1',
      motelId: 'motel-1',
      name: 'Suite',
      description: 'Habitación de prueba',
      idType: 'type-1',
      pricePerHour: 50000,
      roomNumber: '101',
      capacity: 2,
      imageUrls: ['image'],
      isActive: true,
      includedServices: ['Jacuzzi'],
    );

    await dao.saveRoomTypes(const [
      RoomTypeData(id: 'type-1', motelId: 'motel-1', name: 'Suite'),
    ]);
    await dao.saveRooms([room]);
    final rooms = await dao.getRooms();

    expect(rooms, hasLength(1));
    expect(rooms.single.id, room.id);
    expect(rooms.single.includedServices, room.includedServices);
  });

  test('actualiza y elimina tipos mediante CRUD SQLite', () async {
    const type = RoomTypeData(id: 'type-1', motelId: 'motel-1', name: 'Suite');
    await dao.upsertRoomType(type);
    await dao.upsertRoomType(type.copyWith(name: 'Suite premium'));

    expect((await dao.getRoomTypes()).single.name, 'Suite premium');

    await dao.deleteRoomType(type.id);
    expect(await dao.getRoomTypes(), isEmpty);
  });

  test(
    'actualiza, reabre y elimina habitaciones sin afectar otro motel',
    () async {
      await dao.saveRoomTypes(const [
        RoomTypeData(id: 't1', motelId: 'm1', name: 'Suite'),
        RoomTypeData(id: 't2', motelId: 'm2', name: 'Suite'),
      ]);
      RoomVisualData room(String id, String motel, String type, int price) =>
          RoomVisualData(
            id: id,
            motelId: motel,
            name: 'Suite',
            description: 'Descripción',
            idType: type,
            pricePerHour: price,
            roomNumber: '101',
            capacity: 2,
            imageUrls: const [],
            isActive: true,
            includedServices: const ['Jacuzzi'],
          );
      await dao.upsertRoom(room('r1', 'm1', 't1', 100));
      await dao.upsertRoom(room('r2', 'm2', 't2', 200));
      await dao.upsertRoom(room('r1', 'm1', 't1', 300));
      await expectLater(dao.deleteRoomType('t1'), throwsStateError);
      await database.close();
      database = await AppDatabaseProvider.open(
        name: '${directory.path}${Platform.pathSeparator}rooms.db',
      );
      dao = database.roomDao;
      expect(
        (await dao.getRooms()).firstWhere((r) => r.id == 'r1').pricePerHour,
        300,
      );
      await dao.deleteRoom('r1');
      await dao.deleteRoomType('t1');
      expect((await dao.getRooms()).single.motelId, 'm2');
      expect((await dao.getRoomTypes()).single.motelId, 'm2');
    },
  );

  test('migración elimina ejemplos y conserva habitaciones propias', () async {
    await dao.saveRoomTypes(const [
      RoomTypeData(id: 'type-suite', motelId: '1', name: 'Suite'),
      RoomTypeData(id: 'type-loft', motelId: '1', name: 'Loft'),
    ]);
    RoomVisualData room(String id, String type, String number) =>
        RoomVisualData(
          id: id,
          motelId: '1',
          name: 'Habitación',
          description: 'Descripción',
          idType: type,
          pricePerHour: 100,
          roomNumber: number,
          capacity: 2,
          imageUrls: const [],
          isActive: true,
          includedServices: const [],
        );
    await dao.upsertRoom(room('room-101', 'type-suite', '101'));
    await dao.upsertRoom(room('room-personal', 'type-loft', '999'));
    await database.database.execute('PRAGMA user_version = 12');
    await database.close();
    database = await AppDatabaseProvider.open(
      name: '${directory.path}${Platform.pathSeparator}rooms.db',
    );
    dao = database.roomDao;
    expect((await dao.getRooms()).single.id, 'room-personal');
    expect((await dao.getRoomTypes()).single.id, 'type-loft');
  });

  test(
    'limpia ejemplos con la base abierta y permite repetir la limpieza',
    () async {
      await dao.upsertRoomType(
        const RoomTypeData(id: 'type-suite', motelId: '1', name: 'Suite'),
      );
      await dao.upsertRoom(
        const RoomVisualData(
          id: 'room-101',
          motelId: '1',
          name: 'Suite Aurora',
          description: 'Ejemplo',
          idType: 'type-suite',
          pricePerHour: 68000,
          roomNumber: '101',
          capacity: 2,
          imageUrls: [],
          isActive: true,
          includedServices: [],
        ),
      );
      await dao.removeLegacyMockData();
      await dao.removeLegacyMockData();
      expect(await dao.getRooms(), isEmpty);
      expect(await dao.getRoomTypes(), isEmpty);
    },
  );

  test('persiste y recupera el maestro de servicios', () async {
    const services = [
      RoomService(id: 1, name: 'Jacuzzi'),
      RoomService(id: 2, name: 'Luces'),
    ];

    await dao.saveIncludedServices(services);
    final stored = await dao.getIncludedServices();

    expect(stored.map((service) => service.name), ['Jacuzzi', 'Luces']);
  });
}
