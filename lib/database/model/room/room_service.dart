import 'package:floor/floor.dart';

/// Servicio que puede estar incluido en una habitación.
@Entity(
  tableName: 'room_included_services',
  indices: [
    Index(value: ['name'], unique: true),
  ],
)
class RoomService {
  const RoomService({required this.id, required this.name});

  @primaryKey
  final int id;
  final String name;

  factory RoomService.fromJson(Map<String, dynamic> json) =>
      RoomService(id: json['id'] as int, name: json['name'] as String);

  Map<String, dynamic> toJson() => {'id': id, 'name': name};
}
