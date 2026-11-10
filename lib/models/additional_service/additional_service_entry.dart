import 'package:floor/floor.dart';
import 'package:machuco/models/additional_service/additional_service.dart';

/// Persistencia local de un servicio adicional.
@Entity(tableName: 'additional_services')
class AdditionalServiceEntry {
  const AdditionalServiceEntry({
    required this.id,
    required this.motelId,
    required this.name,
    required this.description,
    required this.category,
    required this.price,
    required this.active,
  });

  @PrimaryKey()
  final String id;
  final String motelId;
  final String name;
  final String description;
  final String category;
  final int price;
  final bool active;

  factory AdditionalServiceEntry.fromService(AdditionalService service) {
    return AdditionalServiceEntry(
      id: service.id,
      motelId: service.motelId,
      name: service.name,
      description: service.description,
      category: service.category,
      price: service.price,
      active: service.active,
    );
  }

  AdditionalService toService() => AdditionalService(
    id: id,
    motelId: motelId,
    name: name,
    description: description,
    category: category,
    price: price,
    active: active,
  );
}
