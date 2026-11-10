import 'dart:convert';

import 'package:machuco/models/room/room_models.dart';
import 'package:machuco/models/room/room_service.dart';
import 'package:sqflite/sqflite.dart';

typedef DatabaseProvider = Future<Database> Function();

/// Data Access Object de habitaciones sobre SQLite.
class RoomDao {
  RoomDao(this._databaseProvider);

  final DatabaseProvider _databaseProvider;

  /// La mutación y su evento se confirman juntos o se revierten juntos.
  Future<void> mutateAndEnqueue({
    required String uid,
    required String collection,
    required String id,
    required Map<String, dynamic> payload,
    required Future<void> Function(RoomDao dao) mutate,
  }) async {
    final database = await _databaseProvider();
    await database.transaction((transaction) async {
      final dao = RoomDao(_databaseProvider).._transaction = transaction;
      await mutate(dao);
      await transaction.insert('room_sync_queue', {
        'uid': uid,
        'collection_name': collection,
        'document_id': id,
        'payload': jsonEncode(payload),
      });
    });
  }

  DatabaseExecutor? _transaction;
  Future<DatabaseExecutor> get _executor async =>
      _transaction ?? await _databaseProvider();

  Future<List<Map<String, Object?>>> pendingChanges(String uid) async =>
      (await _databaseProvider()).query(
        'room_sync_queue',
        where: 'uid = ?',
        whereArgs: [uid],
        orderBy: 'sequence ASC',
      );

  Future<void> acknowledgeChange(int sequence) async =>
      (await _databaseProvider()).delete(
        'room_sync_queue',
        where: 'sequence = ?',
        whereArgs: [sequence],
      );

  Future<void> mergeRemote(
    List<RoomTypeData> types,
    List<RoomVisualData> rooms,
    List<String> deletedRooms,
    List<String> deletedTypes,
  ) async {
    final database = await _databaseProvider();
    await database.transaction((transaction) async {
      final pending = await transaction.query('room_sync_queue');
      final protected = pending
          .map((row) => '${row['collection_name']}/${row['document_id']}')
          .toSet();
      for (final type in types) {
        if (!protected.contains('room_types/${type.id}')) {
          await _upsertRoomType(transaction, type);
        }
      }
      for (final id in deletedRooms) {
        if (!protected.contains('rooms/$id')) {
          await transaction.delete('rooms', where: 'id = ?', whereArgs: [id]);
        }
      }
      for (final room in rooms) {
        if (!protected.contains('rooms/${room.id}')) {
          await transaction.insert(
            'rooms',
            _roomToMap(room),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }
      for (final id in deletedTypes) {
        if (!protected.contains('room_types/$id')) {
          await transaction.rawDelete(
            'DELETE FROM room_types WHERE id = ? '
            'AND NOT EXISTS (SELECT 1 FROM rooms WHERE type_id = ?)',
            [id, id],
          );
        }
      }
    });
  }

  Future<String> getDatabasePath() async => (await _databaseProvider()).path;

  /// También limpia bases ya abiertas durante una sesión de desarrollo.
  Future<void> removeLegacyMockData() async {
    final database = await _databaseProvider();
    await database.transaction(deleteLegacyRoomMockData);
  }

  Future<List<RoomVisualData>> getRooms() async {
    final database = await _databaseProvider();
    final rows = await database.query('rooms', orderBy: 'room_number ASC');
    return rows.map(_roomFromMap).toList(growable: false);
  }

  Future<void> saveRooms(List<RoomVisualData> rooms) async {
    final database = await _databaseProvider();
    await database.transaction((transaction) async {
      await transaction.delete('rooms');
      for (final room in rooms) {
        await transaction.insert('rooms', _roomToMap(room));
      }
    });
  }

  Future<void> upsertRoom(RoomVisualData room) async {
    final database = await _executor;
    await database.insert(
      'rooms',
      _roomToMap(room),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteRoom(String roomId) async {
    final database = await _executor;
    await database.delete('rooms', where: 'id = ?', whereArgs: [roomId]);
  }

  Future<List<RoomTypeData>> getRoomTypes() async {
    final database = await _databaseProvider();
    final rows = await database.query('room_types', orderBy: 'name ASC');
    return rows.map(_roomTypeFromMap).toList(growable: false);
  }

  Future<void> saveRoomTypes(List<RoomTypeData> roomTypes) async {
    final database = await _databaseProvider();
    await database.transaction((transaction) async {
      for (final roomType in roomTypes) {
        await _upsertRoomType(transaction, roomType);
      }
    });
  }

  Future<void> upsertRoomType(RoomTypeData roomType) async {
    final database = await _executor;
    await _upsertRoomType(database, roomType);
  }

  Future<void> deleteRoomType(String typeId) async {
    Future<void> remove(DatabaseExecutor database) async {
      final rooms = await database.query(
        'rooms',
        columns: ['id'],
        where: 'type_id = ?',
        whereArgs: [typeId],
        limit: 1,
      );
      if (rooms.isNotEmpty) {
        throw StateError(
          'No puedes eliminar un tipo con habitaciones asociadas.',
        );
      }
      await database.delete('room_types', where: 'id = ?', whereArgs: [typeId]);
    }

    if (_transaction != null) {
      await remove(_transaction!);
    } else {
      await (await _databaseProvider()).transaction(remove);
    }
  }

  Future<List<RoomService>> getIncludedServices() async {
    final database = await _databaseProvider();
    final rows = await database.query(
      'room_included_services',
      orderBy: 'id ASC',
    );
    return rows.map(RoomService.fromJson).toList(growable: false);
  }

  Future<void> saveIncludedServices(List<RoomService> services) async {
    final database = await _databaseProvider();
    await database.transaction((transaction) async {
      await transaction.delete('room_included_services');
      for (final service in services) {
        await transaction.insert(
          'room_included_services',
          service.toJson(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<void> clear() async {
    final database = await _databaseProvider();
    await database.transaction((transaction) async {
      await transaction.delete('rooms');
      await transaction.delete('room_types');
      await transaction.delete('room_included_services');
    });
  }

  RoomVisualData _roomFromMap(Map<String, Object?> map) => RoomVisualData(
    id: map['id']! as String,
    motelId: map['motel_id']! as String,
    name: map['name']! as String,
    description: map['description']! as String,
    idType: map['type_id']! as String,
    pricePerHour: map['price_per_hour']! as int,
    roomNumber: map['room_number']! as String,
    capacity: map['capacity']! as int,
    imageUrls: List<String>.from(
      jsonDecode(map['image_urls_json']! as String) as List,
    ),
    isActive: map['is_active'] == 1,
    includedServices: List<String>.from(
      jsonDecode(map['included_services_json']! as String) as List,
    ),
  );

  Map<String, Object?> _roomToMap(RoomVisualData room) => {
    'id': room.id,
    'motel_id': room.motelId,
    'name': room.name,
    'description': room.description,
    'type_id': room.idType,
    'price_per_hour': room.pricePerHour,
    'room_number': room.roomNumber,
    'capacity': room.capacity,
    'image_urls_json': jsonEncode(room.imageUrls),
    'is_active': room.isActive ? 1 : 0,
    'included_services_json': jsonEncode(room.includedServices),
  };

  RoomTypeData _roomTypeFromMap(Map<String, Object?> map) => RoomTypeData(
    id: map['id']! as String,
    motelId: map['motel_id']! as String,
    name: map['name']! as String,
  );

  Map<String, Object?> _roomTypeToMap(RoomTypeData roomType) => {
    'id': roomType.id,
    'motel_id': roomType.motelId,
    'name': roomType.name,
  };

  Future<void> _upsertRoomType(
    DatabaseExecutor database,
    RoomTypeData roomType,
  ) async {
    final values = _roomTypeToMap(roomType);
    final updated = await database.update(
      'room_types',
      values,
      where: 'id = ?',
      whereArgs: [roomType.id],
    );
    if (updated == 0) await database.insert('room_types', values);
  }
}

/// Los identificadores del antiguo mock están reservados para datos de ejemplo.
Future<void> deleteLegacyRoomMockData(DatabaseExecutor database) async {
  await database.rawDelete('DELETE FROM rooms WHERE id IN (?, ?, ?, ?, ?)', [
    'room-101',
    'room-204',
    'room-206',
    'room-305',
    'room-402',
  ]);
  await database.rawDelete(
    'DELETE FROM room_types WHERE id IN (?, ?, ?, ?) '
    'AND NOT EXISTS (SELECT 1 FROM rooms WHERE rooms.type_id = room_types.id)',
    ['type-suite', 'type-loft', 'type-cabin', 'type-studio'],
  );
}
