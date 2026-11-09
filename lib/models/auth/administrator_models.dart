import 'package:machuco/models/auth/user_profile.dart';

/// Why an administrator-management operation failed, so views can choose a
/// message or a recovery action without parsing raw provider errors.
enum AdministratorsFailureType {
  /// The target is the only active administrator: another must exist first.
  lastAdmin,

  /// The account does not exist anymore (deleted or anonymized meanwhile).
  notFound,

  /// The email already belongs to another account (nothing was touched).
  emailInUse,

  /// `firestore.rules` rejected the operation (not an active administrator).
  permissionDenied,

  /// No connection; retrying is safe.
  network,

  /// Input rejected by the app's validation.
  invalidInput,

  unknown,
}

/// Error of the administrators repository; [message] is safe to show (Spanish).
class AdministratorsRepositoryException implements Exception {
  const AdministratorsRepositoryException(this.type, this.message);

  final AdministratorsFailureType type;
  final String message;

  @override
  String toString() => message;
}

/// Data an administrator types to create another administrator. There is no
/// password: the app generates a temporary one.
class NewAdministratorData {
  const NewAdministratorData({
    required this.firstNames,
    required this.lastNames,
    required this.phoneCountryCodeId,
    required this.phoneNumber,
    required this.email,
  });

  final String firstNames;
  final String lastNames;
  final int phoneCountryCodeId;

  /// Phone including the country dial code (`+573001234567`).
  final String phoneNumber;
  final String email;
}

/// Editable fields of an administrator. Email, role and status never change.
class AdministratorContactChanges {
  const AdministratorContactChanges({
    required this.firstNames,
    required this.lastNames,
    required this.phoneCountryCodeId,
    required this.phoneNumber,
  });

  final String firstNames;
  final String lastNames;
  final int phoneCountryCodeId;
  final String phoneNumber;

  String get fullName => '$firstNames $lastNames'.trim();
}

/// Result of creating an administrator. [temporaryPassword] exists only here:
/// it is never stored or logged, and must be shown to the creator once.
class CreatedAdministrator {
  const CreatedAdministrator({
    required this.profile,
    required this.temporaryPassword,
  });

  final UserProfile profile;
  final String temporaryPassword;

  @override
  String toString() => 'CreatedAdministrator(uid: ${profile.uid})';
}
