import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:machuco/models/owner_management/document_type.dart';
import 'package:machuco/models/owner_management/owner.dart';

/// Representación en Cloud Firestore de un [Owner] local.
///
/// El propietario es un dato de dominio (no un catálogo) y por eso vive en
/// Firestore. El documento se identifica con el mismo id que la fila de
/// SQLite, de modo que la sincronización sea idempotente: subir dos veces el
/// mismo propietario no duplica nada.
class OwnerFirestoreDocument {
  const OwnerFirestoreDocument({required this.owner, required this.updatedBy});

  final Owner owner;

  /// Uid del administrador que hizo el último cambio.
  final String updatedBy;

  factory OwnerFirestoreDocument.fromFirestore(
    String documentId,
    Map<String, dynamic> data,
  ) {
    final documentType = _requiredDocumentType(data, 'documentType');
    final isActive = data['isActive'];
    if (isActive is! bool) {
      throw const FormatException('Campo remoto inválido: isActive.');
    }

    return OwnerFirestoreDocument(
      updatedBy: _requiredString(data, 'updatedBy'),
      owner: Owner(
        id: documentId,
        fullName: _requiredString(data, 'fullName'),
        documentType: documentType,
        documentNumber: _requiredString(data, 'documentNumber'),
        email: _requiredString(data, 'email'),
        phone: _requiredString(data, 'phone'),
        countryCode: _optionalString(data, 'countryCode'),
        countryName: _optionalString(data, 'countryName'),
        address: _optionalString(data, 'address'),
        isActive: isActive,
        isSynchronized: true,
      ),
    );
  }

  Map<String, dynamic> toFirestore() => <String, dynamic>{
    'fullName': owner.fullName,
    'documentType': owner.documentType.name,
    'documentNumber': owner.documentNumber,
    'email': owner.email,
    'phone': owner.phone,
    if (owner.countryCode != null) 'countryCode': owner.countryCode,
    if (owner.countryName != null) 'countryName': owner.countryName,
    if (owner.address != null) 'address': owner.address,
    'isActive': owner.isActive,
    'updatedBy': updatedBy,
    'updatedAt': FieldValue.serverTimestamp(),
  };

  static DocumentType _requiredDocumentType(
    Map<String, dynamic> data,
    String key,
  ) {
    final value = _requiredString(data, key);
    for (final type in DocumentType.values) {
      if (type.name == value || type.code == value) return type;
    }
    throw const FormatException('Campo remoto inválido: documentType.');
  }

  static String _requiredString(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value is! String || value.trim().isEmpty || value != value.trim()) {
      throw FormatException('Campo remoto inválido: $key.');
    }
    return value;
  }

  static String? _optionalString(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value == null) return null;
    if (value is! String || value.trim().isEmpty || value != value.trim()) {
      throw FormatException('Campo remoto inválido: $key.');
    }
    return value;
  }
}
