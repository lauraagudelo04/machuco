/// Servicio que puede estar incluido en una habitación.
class RoomService {
  const RoomService({required this.id, required this.name});

  final int id;
  final String name;

  factory RoomService.fromJson(Map<String, dynamic> json) =>
      RoomService(id: json['id'] as int, name: json['name'] as String);

  Map<String, dynamic> toJson() => {'id': id, 'name': name};
}
