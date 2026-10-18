import 'package:machuco/models/owner_management/document_type.dart';

/// Propietario de uno o varios moteles.
///
/// El [id] lo asigna la capa que crea el propietario. Mientras no exista
/// backend lo genera `OwnerController`; cuando exista, será el identificador
/// que entregue el servidor.
class Owner {
  const Owner({
    required this.id,
    required this.fullName,
    required this.documentType,
    required this.documentNumber,
    required this.email,
    required this.phone,
    this.address,
    this.isActive = true,
  });

  final String id;
  final String fullName;
  final DocumentType documentType;
  final String documentNumber;
  final String email;
  final String phone;
  final String? address;
  final bool isActive;

  /// Documento completo listo para mostrar, por ejemplo `CC 1020304050`.
  String get documentLabel => '${documentType.shortLabel} $documentNumber';

  /// Solo se copian los campos que el módulo permite modificar: el resto
  /// identifica legalmente al propietario y no cambia después del registro.
  Owner copyWith({String? phone, bool? isActive}) => Owner(
    id: id,
    fullName: fullName,
    documentType: documentType,
    documentNumber: documentNumber,
    email: email,
    phone: phone ?? this.phone,
    address: address,
    isActive: isActive ?? this.isActive,
  );

  /// Mapea a un Map para inserción/actualización en SQLite.
  /// Usa documentType.name para ser consistente con OwnerDao._mapToOwner.
  Map<String, dynamic> toMap() => {
        'id': id,
        'full_name': fullName,
        'document_type': documentType.name,
        'document_number': documentNumber,
        'email': email,
        'phone': phone,
        'address': address,
        'is_active': isActive ? 1 : 0,
        'synchronized': 0,
        'created_at': DateTime.now().millisecondsSinceEpoch,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      };

  /// Crea un Owner desde un Map leído de la base de datos.
  factory Owner.fromMap(Map<String, dynamic> map) => Owner(
    id: map['id'] as String,
    fullName: map['full_name'] as String,
    documentType: DocumentType.values
        .firstWhere((e) => e.name == map['document_type'],
        orElse: () => DocumentType.citizenshipCard),
    documentNumber: map['document_number'] as String,
    email: map['email'] as String,
    phone: map['phone'] as String,
    address: map['address'] as String?,
    isActive: map['is_active'] == 1,
  );
}
