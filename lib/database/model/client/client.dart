import 'package:floor/floor.dart';

@Entity(tableName: 'clients')
class ClientEntry {
  @PrimaryKey(autoGenerate: true)
  final int? id;
  final String name;
  final String phone;
  final String email;
  
  @ColumnInfo(name: 'country_code')
  final String countryCode;

  factory ClientEntry.fromJson(Map<String, dynamic> json) {
    return ClientEntry(
      id: json['id'] as int?,
      name: json['name'] as String,
      phone: json['phone'] as String,
      email: json['email'] as String,
      countryCode: json['country_code'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'phone': phone,
      'email': email,
      'country_code': countryCode,
    };
  }

  ClientEntry({
    this.id,
    required this.name,
    required this.phone,
    required this.email,
    required this.countryCode,
  });
}