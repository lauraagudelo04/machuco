/// Datos maestros de un tipo de habitación, administrado por motel.
class RoomTypeData {
  const RoomTypeData({
    required this.id,
    required this.motelId,
    required this.name,
  });

  final String id;
  final String motelId;
  final String name;

  RoomTypeData copyWith({String? id, String? motelId, String? name}) =>
      RoomTypeData(
        id: id ?? this.id,
        motelId: motelId ?? this.motelId,
        name: name ?? this.name,
      );
}

enum RoomPageRole { admin, owner, client }

/// Información propia de una habitación.
///
/// Las reservas, horarios y disponibilidad pertenecen exclusivamente al
/// módulo de Reservas.
class RoomVisualData {
  const RoomVisualData({
    required this.id,
    required this.motelId,
    required this.name,
    required this.description,
    required this.idType,
    required this.pricePerHour,
    required this.roomNumber,
    required this.capacity,
    required this.imageUrls,
    required this.isActive,
    required this.includedServices,
  });

  final String id;
  final String motelId;
  final String name;
  final String description;
  final String idType;
  final int pricePerHour;
  final String roomNumber;
  final int capacity;
  final List<String> imageUrls;
  final bool isActive;
  final List<String> includedServices;

  RoomVisualData copyWith({
    String? id,
    String? motelId,
    String? name,
    String? description,
    String? idType,
    int? pricePerHour,
    String? roomNumber,
    int? capacity,
    List<String>? imageUrls,
    bool? isActive,
    List<String>? includedServices,
  }) => RoomVisualData(
    id: id ?? this.id,
    motelId: motelId ?? this.motelId,
    name: name ?? this.name,
    description: description ?? this.description,
    idType: idType ?? this.idType,
    pricePerHour: pricePerHour ?? this.pricePerHour,
    roomNumber: roomNumber ?? this.roomNumber,
    capacity: capacity ?? this.capacity,
    imageUrls: imageUrls ?? this.imageUrls,
    isActive: isActive ?? this.isActive,
    includedServices: includedServices ?? this.includedServices,
  );
}
