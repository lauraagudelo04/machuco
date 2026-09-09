import 'package:machuco/controllers/room/room_mock_data.dart';
import 'package:machuco/models/room/room_models.dart';

class RoomAdminController {
  RoomAdminController({
    required String motelId,
    List<RoomVisualData>? seedRooms,
  }) : motelId = motelId,
       _rooms = List<RoomVisualData>.from(
         (seedRooms ?? buildRoomMockData()).where(
           (room) => room.motelId == motelId,
         ),
       );

  final String motelId;
  final List<RoomVisualData> _rooms;

  List<RoomVisualData> get rooms => List.unmodifiable(_rooms);

  List<RoomVisualData> filteredRooms({
    required String query,
    required bool sortAscending,
  }) {
    final normalizedQuery = query.trim().toLowerCase();
    final filtered =
        _rooms.where((room) {
          final matchesSearch =
              normalizedQuery.isEmpty ||
              room.name.toLowerCase().contains(normalizedQuery) ||
              room.roomNumber.toLowerCase().contains(normalizedQuery) ||
              room.description.toLowerCase().contains(normalizedQuery);
          return matchesSearch;
        }).toList()..sort(
          (a, b) => sortAscending
              ? a.name.toLowerCase().compareTo(b.name.toLowerCase())
              : b.name.toLowerCase().compareTo(a.name.toLowerCase()),
        );
    return filtered;
  }
}
