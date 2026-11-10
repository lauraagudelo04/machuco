import 'package:machuco/models/auth/person_type.dart';
import 'package:machuco/models/auth/registered_user.dart';

/// Datos de "Completar perfil" tras ingresar con Google o GitHub.
///
/// No lleva correo ni contraseña: el correo es el del proveedor y la
/// credencial es el propio proveedor. [phoneNumber] se guarda tal cual (con
/// el indicativo antepuesto, como en el registro con correo).
final class SocialProfileData {
  const SocialProfileData._({
    required this.role,
    required this.firstNames,
    required this.lastNames,
    required this.phoneCountryCodeId,
    required this.phoneNumber,
    this.birthDate,
    this.personType,
    this.nit,
    this.companyName,
    this.planId,
  });

  factory SocialProfileData.client({
    required String firstNames,
    required String lastNames,
    required int phoneCountryCodeId,
    required String phoneNumber,
    required DateTime birthDate,
  }) => SocialProfileData._(
    role: RegisteredUserRole.client,
    firstNames: firstNames,
    lastNames: lastNames,
    phoneCountryCodeId: phoneCountryCodeId,
    phoneNumber: phoneNumber,
    birthDate: birthDate,
  );

  factory SocialProfileData.owner({
    required String firstNames,
    required String lastNames,
    required int phoneCountryCodeId,
    required String phoneNumber,
    required PersonType personType,
    required String nit,
    String? companyName,
    required int planId,
  }) => SocialProfileData._(
    role: RegisteredUserRole.owner,
    firstNames: firstNames,
    lastNames: lastNames,
    phoneCountryCodeId: phoneCountryCodeId,
    phoneNumber: phoneNumber,
    personType: personType,
    nit: nit,
    companyName: personType == PersonType.juridica ? companyName : null,
    planId: planId,
  );

  /// Solo [RegisteredUserRole.client] u [RegisteredUserRole.owner].
  final RegisteredUserRole role;
  final String firstNames;
  final String lastNames;
  final int phoneCountryCodeId;
  final String phoneNumber;
  final DateTime? birthDate;
  final PersonType? personType;
  final String? nit;
  final String? companyName;
  final int? planId;

  // Sin toString: contiene datos personales (NIT, fecha de nacimiento).
}
