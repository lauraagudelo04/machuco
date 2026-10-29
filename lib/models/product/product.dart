class Product {
  const Product({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.stock,
    required this.isAvailable,
    required this.motelId,
    this.imageUrl,
  });

  final String id;
  final String name;
  final String description;
  final double price;
  final int stock;
  final bool isAvailable;
  final String motelId;
  final String? imageUrl;

  bool get hasStock => stock > 0;

  bool get isActive => isAvailable && hasStock;

  Product copyWith({
    String? id,
    String? name,
    String? description,
    double? price,
    int? stock,
    bool? isAvailable,
    String? motelId,
    String? imageUrl,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      stock: stock ?? this.stock,
      isAvailable: isAvailable ?? this.isAvailable,
      motelId: motelId ?? this.motelId,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'price': price,
      'stock': stock,
      'isAvailable': isAvailable,
      'motelId': motelId,
      'imageUrl': imageUrl,
    };
  }

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as String,
      name: json['name'] as String,
      description: (json['description'] as String?) ?? '',
      price: (json['price'] as num).toDouble(),
      stock: (json['stock'] as num).toInt(),
      isAvailable: json['isAvailable'] as bool,
      motelId: json['motelId'] as String,
      imageUrl: json['imageUrl'] as String?,
    );
  }
}
