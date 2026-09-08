import 'package:machuco/controllers/room/room_mock_data.dart';
import 'package:machuco/models/room/room_models.dart';

class RoomOwnerController {
  RoomOwnerController({
    String motelId = 'motel-eclipse',
    String motelName = 'Motel Eclipse',
    List<RoomVisualData>? seedRooms,
  }) : motelId = motelId,
       _rooms = List<RoomVisualData>.from(
         (seedRooms ??
                 buildRoomMockData(motelId: motelId, motelName: motelName))
             .where((room) => room.motelId == motelId),
       );

  final String motelId;
  List<RoomVisualData> _rooms;

  List<RoomVisualData> get rooms => List.unmodifiable(_rooms);

  List<RoomVisualData> filteredRooms(String query) {
    final normalizedQuery = query.trim().toLowerCase();
    return _rooms.where((room) {
      final matchesSearch =
          normalizedQuery.isEmpty ||
          room.name.toLowerCase().contains(normalizedQuery) ||
          room.roomNumber.toLowerCase().contains(normalizedQuery) ||
          room.includedServices.any(
            (service) => service.toLowerCase().contains(normalizedQuery),
          );
      return matchesSearch;
    }).toList();
  }

  void addRoom(RoomVisualData room) {
    _ensureRoomBelongsToMotel(room);
    _rooms = [..._rooms, room];
  }

  void updateRoom(String roomId, RoomVisualData updatedRoom) {
    _ensureRoomBelongsToMotel(updatedRoom);
    _rooms = _rooms
        .map((room) => room.id == roomId ? updatedRoom : room)
        .toList();
  }

  void addStatusSchedule(String roomId, RoomStatusSchedule schedule) {
    _rooms = _rooms.map((room) {
      if (room.id != roomId) {
        return room;
      }

      final nextSchedules = [...room.statusSchedules, schedule]
        ..sort((a, b) => a.startDateTime.compareTo(b.startDateTime));
      return room.copyWith(statusSchedules: nextSchedules);
    }).toList();
  }

  void _ensureRoomBelongsToMotel(RoomVisualData room) {
    if (room.motelId != motelId) {
      throw ArgumentError.value(
        room.motelId,
        'room.motelId',
        'La habitación debe pertenecer al motel $motelId.',
      );
    }
  }
}
