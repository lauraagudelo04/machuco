class Motel {
  final String id;
  final String ownerId;
  final String name;
  final String email;
  final int roomCount;
  final String nit;
  final String address;
  final String phone;
  final String? description;
  final String? generalLocation;
  final List<String> paymentMethods;
  final List<String> imageUrls;
  final bool isAvailable;

  const Motel({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.email,
    required this.roomCount,
    required this.nit,
    required this.address,
    required this.phone,
    this.description,
    this.generalLocation,
    required this.paymentMethods,
    required this.imageUrls,
    this.isAvailable = true,
  });

  Motel copyWith({
    String? id,
    String? ownerId,
    String? name,
    String? email,
    int? roomCount,
    String? nit,
    String? address,
    String? phone,
    String? description,
    String? generalLocation,
    List<String>? paymentMethods,
    List<String>? imageUrls,
    bool? isAvailable,
  }) {
    return Motel(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      name: name ?? this.name,
      email: email ?? this.email,
      roomCount: roomCount ?? this.roomCount,
      nit: nit ?? this.nit,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      description: description ?? this.description,
      generalLocation: generalLocation ?? this.generalLocation,
      paymentMethods: paymentMethods ?? this.paymentMethods,
      imageUrls: imageUrls ?? this.imageUrls,
      isAvailable: isAvailable ?? this.isAvailable,
    );
  }
}