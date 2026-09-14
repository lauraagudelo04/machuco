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

  /// Indica si [name] ya está en uso por otro tipo de este motel.
  ///
  /// Los espacios externos y las mayúsculas no distinguen dos nombres para
  /// evitar catálogos visualmente duplicados (por ejemplo, ` Suite ` y
  /// `suite`).
  bool isTypeNameDuplicate(String name, {String? excludingTypeId}) {
    final normalizedName = _normalize(name);
    return _types.any(
      (type) =>
          type.motelId == motelId &&
          type.id != excludingTypeId &&
          _normalize(type.name) == normalizedName,
    );
  }

  /// Indica si [roomNumber] ya está en uso por otra habitación de este motel.
  bool isRoomNumberDuplicate(String roomNumber, {String? excludingRoomId}) {
    final normalizedNumber = _normalize(roomNumber);
    return _rooms.any(
      (room) =>
          room.motelId == motelId &&
          room.id != excludingRoomId &&
          _normalize(room.roomNumber) == normalizedNumber,
    );
  }

  void addRoom(RoomVisualData room) => _rooms.add(room);

  void updateRoom(String roomId, RoomVisualData updatedRoom) {
    final index = _rooms.indexWhere(
      (room) => room.id == roomId && room.motelId == motelId,
    );
    if (index != -1) _rooms[index] = updatedRoom;
  }

  void addType(RoomTypeData type) => _types.add(type);

  void updateType(String typeId, String name) {
    final index = _types.indexWhere(
      (type) => type.id == typeId && type.motelId == motelId,
    );
    if (index != -1) _types[index] = _types[index].copyWith(name: name);
  }

  int roomCountForType(String typeId) => _rooms
      .where((room) => room.motelId == motelId && room.idType == typeId)
      .length;

  bool deleteType(String typeId) {
    if (roomCountForType(typeId) > 0) return false;
    _types.removeWhere((type) => type.id == typeId && type.motelId == motelId);
    return true;
  }

  String _normalize(String value) => value.trim().toLowerCase();
}
