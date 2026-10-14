import 'package:floor/floor.dart';

@Entity(tableName: 'clients')
class Client {
  @PrimaryKey(autoGenerate: true)
  final int? id;

  final String name;
  final String phone;
  final String email;

  @ColumnInfo(name: 'country_code')
  final String countryCode;

  final String password;

  Client({
    this.id,
    required this.name,
    required this.phone,
    required this.email,
    required this.countryCode,
    required this.password,
  });

  String get initials {
    if (name.trim().isEmpty) return '';
    final nameParts = name.trim().split(RegExp(r'\s+'));
    if (nameParts.length > 1) {
      return '${nameParts.first[0]}${nameParts.last[0]}'.toUpperCase();
    }
    return nameParts.first[0].toUpperCase();
  }

  String get maskedPassword => '•' * password.length;

  factory Client.fromJson(Map<String, dynamic> json) {
    return Client(
      id: json['id'] as int?,
      name: json['name'] as String,
      phone: json['phone'] as String,
      email: json['email'] as String,
      countryCode: json['country_code'] as String,
      password: json['password'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'phone': phone,
      'email': email,
      'country_code': countryCode,
      'password': password,
    };
  }

  Client copyWith({
    int? id, 
    String? name,
    String? phone,
    String? email,
    String? countryCode,
    String? password,
  }) {
    return Client(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      countryCode: countryCode ?? this.countryCode,
      password: password ?? this.password,
    );
  }
}