/// Registro del maestro `country_phone_codes` (indicativo telefónico por
/// país) expuesto por Supabase y cacheado en SQLite.
class CountryPhoneCode {
  const CountryPhoneCode({
    required this.id,
    required this.isoCode,
    required this.countryName,
    required this.dialCode,
    required this.phoneMinLength,
    required this.phoneMaxLength,
    required this.sortOrder,
    this.flagEmoji,
    this.isActive = true,
    this.isDevelopmentSeed = false,
  });

  final int id;
  final String isoCode;
  final String countryName;
  final String dialCode;
  final String? flagEmoji;
  final int phoneMinLength;
  final int phoneMaxLength;
  final bool isActive;
  final int sortOrder;

  /// `true` solo para la semilla local usada cuando Supabase no está
  /// configurado y no hay caché. No se persiste en SQLite.
  final bool isDevelopmentSeed;

  /// Texto compacto para el selector, p. ej. `🇨🇴 +57` o `CO +57`.
  String get shortLabel => '${flagEmoji ?? isoCode} $dialCode';

  /// Acepta tanto la respuesta REST de Supabase (`is_active` booleano) como
  /// una fila de SQLite (`is_active` 0/1).
  factory CountryPhoneCode.fromMap(Map<String, Object?> map) {
    final rawActive = map['is_active'];
    return CountryPhoneCode(
      id: (map['id']! as num).toInt(),
      isoCode: (map['iso_code']! as String).toUpperCase(),
      countryName: map['country_name']! as String,
      dialCode: map['dial_code']! as String,
      flagEmoji: map['flag_emoji'] as String?,
      phoneMinLength: (map['phone_min_length']! as num).toInt(),
      phoneMaxLength: (map['phone_max_length']! as num).toInt(),
      isActive: rawActive == true || rawActive == 1,
      sortOrder: (map['sort_order']! as num).toInt(),
    );
  }

  /// Fila para SQLite.
  Map<String, Object?> toMap() => {
    'id': id,
    'iso_code': isoCode,
    'country_name': countryName,
    'dial_code': dialCode,
    'flag_emoji': flagEmoji,
    'phone_min_length': phoneMinLength,
    'phone_max_length': phoneMaxLength,
    'is_active': isActive ? 1 : 0,
    'sort_order': sortOrder,
  };

  /// `true` si [query] coincide con el nombre, el código ISO o el indicativo.
  bool matches(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return true;
    return countryName.toLowerCase().contains(normalized) ||
        isoCode.toLowerCase().contains(normalized) ||
        dialCode.contains(normalized);
  }
}

/// Semilla mínima de desarrollo (Colombia +57) para cuando Supabase no está
/// configurado y no existe caché local.
const developmentCountryPhoneCodeSeed = CountryPhoneCode(
  id: 0,
  isoCode: 'CO',
  countryName: 'Colombia',
  dialCode: '+57',
  flagEmoji: '🇨🇴',
  phoneMinLength: 10,
  phoneMaxLength: 10,
  sortOrder: 0,
  isDevelopmentSeed: true,
);
