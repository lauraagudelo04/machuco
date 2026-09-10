import 'package:machuco/controllers/room/room_mock_data.dart';
import 'package:machuco/models/room/room_models.dart';

class RoomAdminController {
  RoomAdminController({
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

  List<RoomVisualData> roomsForType(String typeId, {String query = ''}) {
    final normalized = query.trim().toLowerCase();
    return _rooms.where((room) {
      final matches =
          normalized.isEmpty ||
          room.name.toLowerCase().contains(normalized) ||
          room.roomNumber.toLowerCase().contains(normalized) ||
          room.description.toLowerCase().contains(normalized);
      return room.motelId == motelId && room.idType == typeId && matches;
    }).toList()..sort((a, b) => a.roomNumber.compareTo(b.roomNumber));
  }
}
