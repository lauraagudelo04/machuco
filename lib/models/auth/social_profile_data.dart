import 'package:machuco/models/auth/person_type.dart';
import 'package:machuco/models/auth/phone_verification.dart';
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
    this.phoneProof,
  });

  factory SocialProfileData.client({
    required String firstNames,
    required String lastNames,
    required int phoneCountryCodeId,
    required String phoneNumber,
    required DateTime birthDate,
    PhoneVerificationProof? phoneProof,
  }) => SocialProfileData._(
    role: RegisteredUserRole.client,
    firstNames: firstNames,
    lastNames: lastNames,
    phoneCountryCodeId: phoneCountryCodeId,
    phoneNumber: phoneNumber,
    birthDate: birthDate,
    phoneProof: phoneProof,
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
    PhoneVerificationProof? phoneProof,
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
    phoneProof: phoneProof,
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

  /// SMS verification of [phoneNumber]; `completeProfile` refuses to create the
  /// profile without it (unless that number is already linked to the user).
  final PhoneVerificationProof? phoneProof;

  /// Same data with the proof of the verified phone attached.
  SocialProfileData withPhoneProof(PhoneVerificationProof proof) =>
      SocialProfileData._(
        role: role,
        firstNames: firstNames,
        lastNames: lastNames,
        phoneCountryCodeId: phoneCountryCodeId,
        phoneNumber: phoneNumber,
        birthDate: birthDate,
        personType: personType,
        nit: nit,
        companyName: companyName,
        planId: planId,
        phoneProof: proof,
      );

  // Sin toString: contiene datos personales (NIT, fecha de nacimiento).
}
