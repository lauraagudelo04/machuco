import 'package:machuco/models/owner_management/document_type.dart';

/// Propietario de uno o varios moteles.
///
/// El [id] lo asigna la capa que crea el propietario. Mientras no exista
/// backend lo genera `OwnerService`; cuando exista, será el identificador
/// que entregue el servidor.
class Owner {
  const Owner({
    required this.id,
    required this.fullName,
    required this.documentType,
    required this.documentNumber,
    required this.email,
    required this.phone,
    this.countryCode,
    this.countryName,
    this.address,
    this.isActive = true,
    this.isSynchronized = false,
  });

  final String id;
  final String fullName;
  final DocumentType documentType;
  final String documentNumber;
  final String email;

  /// Número nacional, sin el indicativo del país.
  final String phone;

  /// Indicativo telefónico del país, por ejemplo `+57`.
  ///
  /// Se guarda aparte de [phone] para poder filtrar, validar y mostrar sin
  /// partir un texto concatenado. Los registros anteriores a la separación
  /// pueden no tenerlo.
  final String? countryCode;

  /// Nombre del país del indicativo, por ejemplo `Colombia`.
  final String? countryName;

  final String? address;
  final bool isActive;

  /// `false` mientras el registro solo exista en SQLite local; pasa a `true`
  /// cuando la nube confirma que lo recibió.
  final bool isSynchronized;

  /// Documento completo listo para mostrar, por ejemplo `CC 1020304050`.
  String get documentLabel => '${documentType.shortLabel} $documentNumber';

  /// Teléfono listo para mostrar, con su indicativo cuando se conoce.
  String get phoneWithDialCode {
    final dialCode = countryCode;
    return dialCode == null ? phone : '$dialCode $phone';
  }

  /// Solo se copian los campos que el módulo permite modificar: el resto
  /// identifica legalmente al propietario y no cambia después del registro.
  ///
  /// [isSynchronized] se copia para que otras capas puedan marcarlo sin perder
  /// los demás datos.
  Owner copyWith({
    String? phone,
    String? countryCode,
    String? countryName,
    bool? isActive,
    bool? isSynchronized,
  }) => Owner(
    id: id,
    fullName: fullName,
    documentType: documentType,
    documentNumber: documentNumber,
    email: email,
    phone: phone ?? this.phone,
    countryCode: countryCode ?? this.countryCode,
    countryName: countryName ?? this.countryName,
    address: address,
    isActive: isActive ?? this.isActive,
    isSynchronized: isSynchronized ?? this.isSynchronized,
  );
}
