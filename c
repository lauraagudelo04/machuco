class PhoneCountryCode {
  final int id;
  final String countryCode;
  final String countryName;
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
}