/// The three MACHUCO roles, as represented in the app's own domain model.
///
/// See the user profiles described in README.md#perfiles for what each
/// role can access in the product.
enum RegisteredUserRole { admin, client, owner }

/// Maps a [RegisteredUserRole] to the string value stored in Auth0
/// user/app metadata and sent to the backend users API.
extension RegisteredUserRoleValue on RegisteredUserRole {
  String get metadataValue => switch (this) {
    RegisteredUserRole.admin => 'admin',
    RegisteredUserRole.client => 'client',
    RegisteredUserRole.owner => 'owner',
  };
}

/// Parses a role coming from an external source (Auth0 claims or the
/// backend users API) into a [RegisteredUserRole].
///
/// Accepts a few historical/alternate spellings (`administrator`,
/// `final_user`, `finaluser`, `user`) for compatibility with data that may
/// have been created before the metadata value was standardized. Any
/// unrecognized value defaults to [RegisteredUserRole.client] rather than
/// throwing, so an unexpected claim never blocks login.
RegisteredUserRole roleFromMetadataValue(String value) {
  final normalized = value.trim().toLowerCase();
  return switch (normalized) {
    'admin' || 'administrator' => RegisteredUserRole.admin,
    'owner' => RegisteredUserRole.owner,
    'client' ||
    'final_user' ||
    'finaluser' ||
    'user' => RegisteredUserRole.client,
    _ => RegisteredUserRole.client,
  };
}

/// A user as known by the MACHUCO users directory, independent of the
/// Auth0 session that authenticated them.
///
/// Used by [RegisteredUserDirectory] implementations to list and persist
/// application users beyond what an Auth0 session token carries.
class RegisteredUser {
  const RegisteredUser({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phoneNumber,
    required this.role,
    required this.createdAt,
  });

  final String id;
  final String fullName;
  final String email;
  final String phoneNumber;
  final RegisteredUserRole role;
  final DateTime createdAt;

  /// Builds a [RegisteredUser] from the backend users API response shape.
  ///
  /// Missing or unparsable fields fall back to safe placeholder values
  /// (e.g. `'Usuario sin nombre'`, `'sin-correo'`) instead of throwing, so a
  /// malformed record does not break the whole user list.
  factory RegisteredUser.fromJson(Map<String, dynamic> json) {
    final rawCreatedAt = json['createdAt']?.toString() ?? '';
    final createdAt =
        DateTime.tryParse(rawCreatedAt)?.toUtc() ?? DateTime.now().toUtc();
    return RegisteredUser(
      id: json['id']?.toString() ?? '',
      fullName: json['fullName']?.toString() ?? 'Usuario sin nombre',
      email: json['email']?.toString() ?? 'sin-correo',
      phoneNumber: json['phoneNumber']?.toString() ?? '',
      role: roleFromMetadataValue(json['role']?.toString() ?? ''),
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'fullName': fullName,
    'email': email,
    'phoneNumber': phoneNumber,
    'role': role.metadataValue,
    'createdAt': createdAt.toUtc().toIso8601String(),
  };
}
