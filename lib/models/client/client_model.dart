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

  Map<String, dynamic> toJson() => {
    'id': id,
    'uid': uid,
    'name': name,
    'phone': phone,
    'email': email,
    'countryCode': countryCode,
  };

  factory ClientModel.fromJson(Map<String, dynamic> json) => ClientModel(
    id: json['id'] as int?,
    uid: json['uid'] as String?,
    name: (json['name'] ?? '') as String,
    phone: (json['phone'] ?? '') as String,
    email: (json['email'] ?? '') as String,
    countryCode: (json['countryCode'] ?? '+57') as String,
  );

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