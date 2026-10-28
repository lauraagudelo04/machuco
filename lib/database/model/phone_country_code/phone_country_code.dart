import 'package:floor/floor.dart';

@Entity(tableName: 'phone_country_codes')
class PhoneCountryCode {
  @PrimaryKey()
  final int id;

  @ColumnInfo(name: 'country_code')
  final String countryCode;

  @ColumnInfo(name: 'country_name')
  final String countryName;

  @ColumnInfo(name: 'calling_code')
  final String callingCode;

  final bool active;

  const PhoneCountryCode({
    required this.id,
    required this.countryCode,
    required this.countryName,
    required this.callingCode,
    required this.active,
  });

  factory PhoneCountryCode.fromJson(Map<String, dynamic> json) {
    return PhoneCountryCode(
      id: json['id'] as int,
      countryCode: json['country_code'] as String,
      countryName: json['country_name'] as String,
      callingCode: json['calling_code'] as String,
      active: json['active'] as bool? ?? true,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'country_code': countryCode,
      'country_name': countryName,
      'calling_code': callingCode,
      'active': active,
    };
  }
}