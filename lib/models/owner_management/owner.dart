import 'package:machuco/models/auth/account_status.dart';
import 'package:machuco/models/owner_management/document_type.dart';

/// Propietario de uno o varios moteles.
///
/// Cada propietario es un usuario registrado: su [id] es el uid de Firebase
/// Auth y el identificador del documento `users/{uid}`. El administrador crea
/// la cuenta con una contraseña temporal y el propietario la cambia al entrar.
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
    this.accountStatus,
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

  /// `true` cuando `accountStatus == active`.
  final bool isActive;

  /// Estado de la cuenta en `users/{uid}.accountStatus`.
  ///
  /// Es `null` en las filas locales antiguas, anteriores a la sincronización
  /// con la colección `users`.
  final AccountStatus? accountStatus;

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

  /// `true` si es un dato demo sembrado en SQLite: nunca viaja a Firebase para
  /// no crear cuentas de acceso de mentira.
  bool get isLocalDemo => id.startsWith('owner-');

  /// `true` mientras la cuenta espera la decisión de un administrador.
  bool get isPendingApproval => accountStatus == AccountStatus.pendingApproval;

  /// Devuelve una copia con otro identificador (el uid que asigna Firebase
  /// Auth al crear la cuenta).
  Owner withId(String newId) => Owner(
    id: newId,
    fullName: fullName,
    documentType: documentType,
    documentNumber: documentNumber,
    email: email,
    phone: phone,
    countryCode: countryCode,
    countryName: countryName,
    address: address,
    isActive: isActive,
    accountStatus: accountStatus,
    isSynchronized: isSynchronized,
  );

  /// Copia con los campos que el panel permite modificar.
  Owner copyWith({
    String? fullName,
    DocumentType? documentType,
    String? documentNumber,
    String? phone,
    String? countryCode,
    String? countryName,
    String? address,
    bool? isActive,
    AccountStatus? accountStatus,
    bool? isSynchronized,
  }) => Owner(
    id: id,
    fullName: fullName ?? this.fullName,
    documentType: documentType ?? this.documentType,
    documentNumber: documentNumber ?? this.documentNumber,
    email: email,
    phone: phone ?? this.phone,
    countryCode: countryCode ?? this.countryCode,
    countryName: countryName ?? this.countryName,
    address: address ?? this.address,
    isActive: isActive ?? this.isActive,
    accountStatus: accountStatus ?? this.accountStatus,
    isSynchronized: isSynchronized ?? this.isSynchronized,
  );
}
