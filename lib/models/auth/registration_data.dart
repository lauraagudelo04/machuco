import 'package:machuco/models/auth/person_type.dart';
import 'package:machuco/models/auth/registered_user.dart';

/// Datos del formulario de registro por rol.
///
/// - Cliente: [RegistrationData.client] (incluye [birthDate]).
/// - Propietario: [RegistrationData.owner] (incluye [personType], [nit],
///   [companyName] y [planId]).
///
/// Nunca se crea un administrador desde el registro público.
final class RegistrationData {
  const RegistrationData._({
    required this.role,
    required this.firstNames,
    required this.lastNames,
    required this.phoneCountryCodeId,
    required this.phoneNumber,
    required this.email,
    required this.password,
    this.birthDate,
    this.personType,
    this.nit,
    this.companyName,
    this.planId,
  });

  factory RegistrationData.client({
    required String firstNames,
    required String lastNames,
    required int phoneCountryCodeId,
    required String phoneNumber,
    required String email,
    required String password,
    required DateTime birthDate,
  }) => RegistrationData._(
    role: RegisteredUserRole.client,
    firstNames: firstNames,
    lastNames: lastNames,
    phoneCountryCodeId: phoneCountryCodeId,
    phoneNumber: phoneNumber,
    email: email,
    password: password,
    birthDate: birthDate,
  );

  /// [companyName] solo aplica a persona jurídica; se ignora en natural.
  factory RegistrationData.owner({
    required String firstNames,
    required String lastNames,
    required int phoneCountryCodeId,
    required String phoneNumber,
    required String email,
    required String password,
    required PersonType personType,
    required String nit,
    String? companyName,
    required int planId,
  }) => RegistrationData._(
    role: RegisteredUserRole.owner,
    firstNames: firstNames,
    lastNames: lastNames,
    phoneCountryCodeId: phoneCountryCodeId,
    phoneNumber: phoneNumber,
    email: email,
    password: password,
    personType: personType,
    nit: nit,
    companyName: personType == PersonType.juridica ? companyName : null,
    planId: planId,
  );

  final RegisteredUserRole role;
  final String firstNames;
  final String lastNames;

  /// Id del maestro `phone_country_codes` seleccionado.
  final int phoneCountryCodeId;

  /// Celular solo con dígitos, sin indicativo. `LoginController` antepone el
  /// indicativo antes de enviarlo al servicio.
  final String phoneNumber;
  final String email;
  final String password;

  final DateTime? birthDate;
  final PersonType? personType;
  final String? nit;
  final String? companyName;
  final int? planId;

  String get fullName => '${firstNames.trim()} ${lastNames.trim()}'.trim();

  RegistrationData copyWith({
    String? firstNames,
    String? lastNames,
    int? phoneCountryCodeId,
    String? phoneNumber,
    String? email,
    String? nit,
    String? companyName,
  }) => RegistrationData._(
    role: role,
    firstNames: firstNames ?? this.firstNames,
    lastNames: lastNames ?? this.lastNames,
    phoneCountryCodeId: phoneCountryCodeId ?? this.phoneCountryCodeId,
    phoneNumber: phoneNumber ?? this.phoneNumber,
    email: email ?? this.email,
    password: password,
    birthDate: birthDate,
    personType: personType,
    nit: nit ?? this.nit,
    companyName: companyName ?? this.companyName,
    planId: planId,
  );

  // Sin toString: contiene la contraseña y datos personales.
}
