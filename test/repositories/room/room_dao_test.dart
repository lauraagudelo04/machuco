import 'package:flutter_test/flutter_test.dart';
import 'package:machuco/database/app_database.dart';
import 'package:machuco/models/room/room_models.dart';
import 'package:machuco/models/room/room_service.dart';
import 'package:machuco/repositories/room/room_dao.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late AppDatabase database;
  late RoomDao dao;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    database = AppDatabase(
      factory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    );
    dao = database.roomDao;
  });

  tearDown(() => database.close());

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
