enum AdditionalServiceIcon { shield, cloud, support, cleaning, miscellaneous }

class AdditionalService {
  const AdditionalService({
    required this.id,
    required this.icon,
    required this.name,
    required this.description,
    required this.category,
    required this.price,
    required this.active,
  });

  final String id;
  final AdditionalServiceIcon icon;
  final String name;
  final String description;
  final String category;
  final int price;
  final bool active;

  AdditionalService copyWith({
    String? name,
    String? description,
    String? category,
    int? price,
    bool? active,
  }) {
    return AdditionalService(
      id: id,
      icon: icon,
      name: name ?? this.name,
      description: description ?? this.description,
      category: category ?? this.category,
      price: price ?? this.price,
      active: active ?? this.active,
    );
  }
}
