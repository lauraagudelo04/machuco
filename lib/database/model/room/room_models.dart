import 'package:floor/floor.dart';

/// Datos maestros de un tipo de habitación, administrado por motel.
@Entity(
  tableName: 'room_types',
  indices: [
    Index(value: ['motel_id', 'name'], unique: true),
  ],
)
class RoomTypeData {
  const RoomTypeData({
    required this.id,
    required this.motelId,
    required this.name,
  });

  @primaryKey
  final String id;
  @ColumnInfo(name: 'motel_id')
  final String motelId;
  final String name;

  RoomTypeData copyWith({String? id, String? motelId, String? name}) =>
      RoomTypeData(
        id: id ?? this.id,
        motelId: motelId ?? this.motelId,
        name: name ?? this.name,
      );

  factory RoomTypeData.fromJson(Map<String, dynamic> json) => RoomTypeData(
    id: json['id'] as String,
    motelId: json['motelId'] as String,
    name: json['name'] as String,
  );

  Map<String, dynamic> toJson() => {'id': id, 'motelId': motelId, 'name': name};
}

enum RoomPageRole { admin, owner, client }

/// Información propia de una habitación.
///
/// Las reservas, horarios y disponibilidad pertenecen exclusivamente al
/// módulo de Reservas.
@Entity(
  tableName: 'rooms',
  foreignKeys: [
    ForeignKey(
      childColumns: ['type_id'],
      parentColumns: ['id'],
      entity: RoomTypeData,
      onUpdate: ForeignKeyAction.cascade,
      onDelete: ForeignKeyAction.restrict,
    ),
  ],
  indices: [
    Index(value: ['motel_id', 'room_number'], unique: true),
  ],
)
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

  @primaryKey
  final String id;
  @ColumnInfo(name: 'motel_id')
  final String motelId;
  final String name;
  final String description;
  @ColumnInfo(name: 'type_id')
  final String idType;
  @ColumnInfo(name: 'price_per_hour')
  final int pricePerHour;
  @ColumnInfo(name: 'room_number')
  final String roomNumber;
  final int capacity;
  @ColumnInfo(name: 'image_urls_json')
  final List<String> imageUrls;
  @ColumnInfo(name: 'is_active')
  final bool isActive;
  @ColumnInfo(name: 'included_services_json')
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

  factory RoomVisualData.fromJson(Map<String, dynamic> json) => RoomVisualData(
    id: json['id'] as String,
    motelId: json['motelId'] as String,
    name: json['name'] as String,
    description: json['description'] as String,
    idType: json['idType'] as String,
    pricePerHour: json['pricePerHour'] as int,
    roomNumber: json['roomNumber'] as String,
    capacity: json['capacity'] as int,
    imageUrls: List<String>.from(json['imageUrls'] as List),
    isActive: json['isActive'] as bool,
    includedServices: List<String>.from(json['includedServices'] as List),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'motelId': motelId,
    'name': name,
    'description': description,
    'idType': idType,
    'pricePerHour': pricePerHour,
    'roomNumber': roomNumber,
    'capacity': capacity,
    'imageUrls': imageUrls,
    'isActive': isActive,
    'includedServices': includedServices,
  };
}
