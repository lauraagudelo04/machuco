import 'package:machuco/database/model/phone_country_code/phone_country_code.dart';

/// Indicativo telefónico por país que usa el formulario de registro.
///
/// Se construye a partir del maestro `phone_country_codes` de Supabase
/// (cacheado en SQLite con la entidad compartida [PhoneCountryCode]). La
/// bandera se dibuja en la UI con `country_flags` a partir de [isoCode].
class CountryPhoneCode {
  const CountryPhoneCode({
    required this.id,
    required this.isoCode,
    required this.countryName,
    required this.dialCode,
    this.phoneMinLength = defaultPhoneMinLength,
    this.phoneMaxLength = defaultPhoneMaxLength,
    this.isActive = true,
    this.isDevelopmentSeed = false,
  });

  /// El maestro de Supabase todavía no publica la longitud del celular por
  /// país; mientras tanto se usa el rango del plan de numeración E.164.
  static const defaultPhoneMinLength = 7;
  static const defaultPhoneMaxLength = 15;

  /// Convierte la fila cacheada en SQLite (o recibida de Supabase).
  factory CountryPhoneCode.fromEntry(PhoneCountryCode entry) {
    return CountryPhoneCode(
      id: entry.id,
      isoCode: entry.countryCode.trim().toUpperCase(),
      countryName: entry.countryName.trim(),
      dialCode: entry.callingCode.trim(),
      isActive: entry.active,
    );
  }

  final int id;

  /// Código ISO 3166-1 alfa-2, p. ej. `CO`.
  final String isoCode;
  final String countryName;

  /// Con `+`, p. ej. `+57`.
  final String dialCode;
  final int phoneMinLength;
  final int phoneMaxLength;
  final bool isActive;

  /// `true` solo para la semilla local usada cuando Supabase no está
  /// configurado y no hay caché. No se persiste en SQLite.
  final bool isDevelopmentSeed;

  /// Texto compacto para lectores de pantalla y pruebas, p. ej. `CO +57`.
  String get shortLabel => '$isoCode $dialCode';

  /// `true` si [query] coincide con el nombre, el código ISO o el indicativo.
  /// El filtro es en memoria: caracteres como `%`, `'` o `--` son texto.
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
  phoneMinLength: 10,
  phoneMaxLength: 10,
  isDevelopmentSeed: true,
);
