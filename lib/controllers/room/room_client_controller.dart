import 'package:machuco/controllers/room/room_mock_data.dart';
import 'package:machuco/models/room/room_models.dart';

/// Consulta equivalente a Tipo INNER JOIN Habitaciones, filtrada por motel e
/// isActive, sin duplicar los tipos que tengan varias habitaciones activas.
class RoomClientController {
  RoomClientController({
    required this.motelId,
    List<RoomVisualData>? seedRooms,
    List<RoomTypeData>? seedTypes,
  }) : _rooms = List.of(seedRooms ?? buildRoomMockData()),
       _types = List.of(seedTypes ?? buildRoomTypeMockData());

  final String motelId;
  final List<RoomVisualData> _rooms;
  final List<RoomTypeData> _types;

  List<RoomTypeData> get activeRoomTypes {
    final ids = _rooms
        .where((room) => room.motelId == motelId && room.isActive)
        .map((room) => room.idType)
        .toSet();
    return _types
        .where((type) => type.motelId == motelId && ids.contains(type.id))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  /// Adaptador temporal para la ruta actual de Reservas, que todavía recibe
  /// una habitación. Reservas sustituirá esta selección cuando acepte el tipo.
  RoomVisualData? firstActiveRoomForType(String typeId) {
    final rooms =
        _rooms
            .where(
              (room) =>
                  room.motelId == motelId &&
                  room.idType == typeId &&
                  room.isActive,
            )
            .toList()
          ..sort((a, b) => a.roomNumber.compareTo(b.roomNumber));
    return rooms.firstOrNull;
  }
}
