import 'package:machuco/controllers/room/room_controller_support.dart';
import 'package:machuco/controllers/room/room_mock_data.dart';
import 'package:machuco/models/room/room_models.dart';

class RoomClientController {
  RoomClientController({
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

  List<RoomVisualData> availableRooms({
    required DateTime? start,
    required DateTime? end,
  }) {
    if (reservationTotalHours(start, end) == null ||
        start == null ||
        end == null) {
      return const [];
    }

    return _rooms.where((room) {
      return roomIsAvailableForRange(room, start, end);
    }).toList()..sort((a, b) => a.pricePerHour.compareTo(b.pricePerHour));
  }
}
