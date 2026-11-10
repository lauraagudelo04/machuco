import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:machuco/models/additional_service/additional_service.dart';

/// Representación en Firestore de un [AdditionalService].
///
/// [ownerId] es un campo de autorización (quién creó el servicio) y no
/// pertenece al esquema local de SQLite, por eso se guarda aparte.
class AdditionalServiceFirestoreDocument {
  const AdditionalServiceFirestoreDocument({
    required this.ownerId,
    required this.service,
  });

  final String ownerId;
  final AdditionalService service;

  /// Lanza [FormatException] si falta un campo obligatorio o tiene otro tipo.
  factory AdditionalServiceFirestoreDocument.fromFirestore(
    String documentId,
    Map<String, dynamic> data,
  ) {
    final price = data['price'];
    final active = data['active'];
    if (price is! int || price <= 0) {
      throw const FormatException('Precio remoto de servicio inválido.');
    }
    if (active is! bool) {
      throw const FormatException('Estado remoto de servicio inválido.');
    }
    return AdditionalServiceFirestoreDocument(
      ownerId: _requiredString(data, 'ownerId'),
      service: AdditionalService(
        id: documentId,
        motelId: _requiredString(data, 'motelId'),
        name: _requiredString(data, 'name'),
        description: _requiredString(data, 'description'),
        category: _requiredString(data, 'category'),
        price: price,
        active: active,
      ),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'ownerId': ownerId,
    'motelId': service.motelId,
    'name': service.name,
    'description': service.description,
    'category': service.category,
    'price': service.price,
    'active': service.active,
    'updatedAt': FieldValue.serverTimestamp(),
  };

  /// Campos que cambian al editar un servicio existente. Nunca incluye
  /// `ownerId` ni `motelId`: las reglas los tratan como inmutables.
  static Map<String, dynamic> updateData(AdditionalService service) => {
    'name': service.name,
    'description': service.description,
    'category': service.category,
    'price': service.price,
    'active': service.active,
    'updatedAt': FieldValue.serverTimestamp(),
  };

  static String _requiredString(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value is String && value.isNotEmpty) return value;
    throw FormatException('Campo remoto "$key" inválido.');
  }
}
