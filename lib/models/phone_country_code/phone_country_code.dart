/// Código telefónico de país expuesto por el maestro remoto de Supabase
/// (tabla `phone_country_codes`).
class PhoneCountryCode {
  const PhoneCountryCode({
    required this.id,
    required this.countryCode,
    required this.countryName,
    required this.callingCode,
    required this.active,
  });

  final int id;
  final String countryCode;
  final String countryName;
  final String callingCode;
  final bool active;

  factory PhoneCountryCode.fromJson(Map<String, dynamic> json) =>
      PhoneCountryCode(
        id: (json['id'] as num).toInt(),
        countryCode: json['country_code'] as String,
        countryName: json['country_name'] as String,
        callingCode: json['calling_code'] as String,
        active: json['active'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'country_code': countryCode,
    'country_name': countryName,
    'calling_code': callingCode,
    'active': active,
  };
}
