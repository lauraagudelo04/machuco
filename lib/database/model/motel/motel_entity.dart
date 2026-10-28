import 'dart:convert';

import 'package:floor/floor.dart';
import 'package:machuco/models/motel/motel_model.dart';

@Entity(tableName: 'motels')
class MotelEntity {
  @PrimaryKey()
  final String id;

  @ColumnInfo(name: 'owner_id')
  final String ownerId;

  final String name;

  final String email;

  @ColumnInfo(name: 'room_count')
  final int roomCount;

  final String nit;

  final String address;

  final String phone;

  final String? description;

  @ColumnInfo(name: 'general_location')
  final String? generalLocation;

  @ColumnInfo(name: 'payment_methods_json')
  final String paymentMethodsJson;

  @ColumnInfo(name: 'image_urls_json')
  final String imageUrlsJson;

  @ColumnInfo(name: 'is_available')
  final int isAvailable;

  const MotelEntity({
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
    required this.paymentMethodsJson,
    required this.imageUrlsJson,
    required this.isAvailable,
  });

  factory MotelEntity.fromModel(Motel motel) {
    return MotelEntity(
      id: motel.id,
      ownerId: motel.ownerId,
      name: motel.name,
      email: motel.email,
      roomCount: motel.roomCount,
      nit: motel.nit,
      address: motel.address,
      phone: motel.phone,
      description: motel.description,
      generalLocation: motel.generalLocation,
      paymentMethodsJson: jsonEncode(motel.paymentMethods),
      imageUrlsJson: jsonEncode(motel.imageUrls),
      isAvailable: motel.isAvailable ? 1 : 0,
    );
  }

  Motel toModel() {
    List<String> paymentMethods = const [];
    List<String> imageUrls = const [];

    try {
      final decodedPayment = jsonDecode(paymentMethodsJson);
      if (decodedPayment is List) {
        paymentMethods = decodedPayment.map((e) => e.toString()).toList();
      }
    } catch (_) {
      paymentMethods = const [];
    }

    try {
      final decodedImages = jsonDecode(imageUrlsJson);
      if (decodedImages is List) {
        imageUrls = decodedImages.map((e) => e.toString()).toList();
      }
    } catch (_) {
      imageUrls = const [];
    }

    return Motel(
      id: id,
      ownerId: ownerId,
      name: name,
      email: email,
      roomCount: roomCount,
      nit: nit,
      address: address,
      phone: phone,
      description: description,
      generalLocation: generalLocation,
      paymentMethods: paymentMethods,
      imageUrls: imageUrls,
      isAvailable: isAvailable == 1,
    );
  }
}
