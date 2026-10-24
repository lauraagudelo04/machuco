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
}
