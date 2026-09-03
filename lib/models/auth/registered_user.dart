enum RegisteredUserRole { administrator, finalUser, owner }

extension RegisteredUserRoleValue on RegisteredUserRole {
  String get metadataValue => switch (this) {
    RegisteredUserRole.administrator => 'administrator',
    RegisteredUserRole.finalUser => 'final_user',
    RegisteredUserRole.owner => 'owner',
  };
}

RegisteredUserRole roleFromMetadataValue(String value) {
  return switch (value.trim().toLowerCase()) {
    'administrator' => RegisteredUserRole.administrator,
    'owner' => RegisteredUserRole.owner,
    _ => RegisteredUserRole.finalUser,
  };
}

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
