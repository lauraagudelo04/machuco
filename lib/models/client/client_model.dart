class ClientModel {
  const ClientModel({
    this.id,
    required this.name,
    required this.phone,
    required this.email,
    required this.countryCode,
    required this.password,
  });

  final int? id;
  final String name;
  final String phone;
  final String email;
  final String countryCode;
  final String password;

  String get initials {
    if (name.trim().isEmpty) return '';
    final nameParts = name.trim().split(RegExp(r'\s+'));
    if (nameParts.length > 1) {
      return '${nameParts.first[0]}${nameParts.last[0]}'.toUpperCase();
    }
    return nameParts.first[0].toUpperCase();
  }

  String get maskedPassword => '•' * password.length;

  ClientModel copyWith({
    int? id,
    String? name,
    String? phone,
    String? email,
    String? countryCode,
    String? password,
  }) {
    return ClientModel(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      countryCode: countryCode ?? this.countryCode,
      password: password ?? this.password,
    );
  }
}