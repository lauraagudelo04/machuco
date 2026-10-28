/// Credenciales del maestro de códigos telefónicos de país en Supabase.
///
/// Se inyectan en tiempo de compilación para no dejar secretos en el
/// repositorio, por ejemplo:
///
/// ```
/// flutter run \
///   --dart-define=SUPABASE_URL=https://ogrbbuwtsyezegkpwtsl.supabase.co \
///   --dart-define=SUPABASE_ANON_KEY=sb_publishable_Wv16MVxsTzA89lBeocarLQ_YL33Ya_E
/// ```
abstract final class SupabasePhoneCountryCodeConfig {
  static const baseUrl = String.fromEnvironment('SUPABASE_URL');
  static const apiKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static bool get isConfigured =>
      baseUrl.trim().isNotEmpty && apiKey.trim().isNotEmpty;
}
