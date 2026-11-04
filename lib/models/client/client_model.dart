class ClientModel {
  const ClientModel({
    this.id,
    this.uid,
    required this.name,
    required this.phone,
    required this.email,
    required this.countryCode,
  });

  final int? id;
  final String? uid;
  final String name;
  final String phone;
  final String email;
  final String countryCode;

  String get initials {
    if (name.trim().isEmpty) return '';
    final nameParts = name.trim().split(RegExp(r'\s+'));
    if (nameParts.length > 1) {
      return '${nameParts.first[0]}${nameParts.last[0]}'.toUpperCase();
    }
    return nameParts.first[0].toUpperCase();
  }

  ClientModel copyWith({
    int? id,
    String? uid,
    String? name,
    String? phone,
    String? email,
    String? countryCode,
  }) {
    return ClientModel(
      id: id ?? this.id,
      uid: uid ?? this.uid,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      countryCode: countryCode ?? this.countryCode,
    );
  }
}