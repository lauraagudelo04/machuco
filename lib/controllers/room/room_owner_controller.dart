import 'package:machuco/controllers/room/room_mock_data.dart';
import 'package:machuco/models/room/room_models.dart';

class RoomOwnerController {
  RoomOwnerController({
    required this.motelId,
    List<RoomVisualData>? seedRooms,
    List<RoomTypeData>? seedTypes,
  }) : _rooms = List.of(seedRooms ?? buildRoomMockData()),
       _types = List.of(seedTypes ?? buildRoomTypeMockData());

  final String motelId;
  final List<RoomVisualData> _rooms;
  final List<RoomTypeData> _types;

  List<RoomTypeData> get roomTypes =>
      _types.where((type) => type.motelId == motelId).toList()
        ..sort((a, b) => a.name.compareTo(b.name));

  List<RoomVisualData> roomsForType(String typeId, String query) {
    final normalized = query.trim().toLowerCase();
    return _rooms.where((room) {
      final matches =
          normalized.isEmpty ||
          room.name.toLowerCase().contains(normalized) ||
          room.roomNumber.toLowerCase().contains(normalized) ||
          room.includedServices.any(
            (service) => service.toLowerCase().contains(normalized),
          );
      return room.motelId == motelId && room.idType == typeId && matches;
    }).toList()..sort((a, b) => a.roomNumber.compareTo(b.roomNumber));
  }

  void addRoom(RoomVisualData room) => _rooms.add(room);

  void updateRoom(String roomId, RoomVisualData updatedRoom) {
    final index = _rooms.indexWhere((room) => room.id == roomId);
    if (index != -1) _rooms[index] = updatedRoom;
  }

  void addType(RoomTypeData type) => _types.add(type);

  void updateType(String typeId, String name) {
    final index = _types.indexWhere((type) => type.id == typeId);
    if (index != -1) _types[index] = _types[index].copyWith(name: name);
  }

  int roomCountForType(String typeId) => _rooms
      .where((room) => room.motelId == motelId && room.idType == typeId)
      .length;

  bool deleteType(String typeId) {
    if (roomCountForType(typeId) > 0) return false;
    _types.removeWhere((type) => type.id == typeId);
    return true;
  }
}
