class AdditionalService {
  const AdditionalService({
    required this.id,
    required this.motelId,
    required this.name,
    required this.description,
    required this.category,
    required this.price,
    required this.active,
  });

  final int id;
  final int motelId;
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
      motelId: motelId,
      name: name ?? this.name,
      description: description ?? this.description,
      category: category ?? this.category,
      price: price ?? this.price,
      active: active ?? this.active,
    );
  }
}
