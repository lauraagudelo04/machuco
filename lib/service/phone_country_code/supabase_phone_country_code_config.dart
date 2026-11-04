/// Credenciales del maestro de códigos telefónicos de país en Supabase.
///
/// Los valores por defecto corresponden al proyecto de desarrollo y permiten
/// ejecutar la app con `flutter run` sin argumentos. Se pueden sobrescribir en
/// tiempo de compilación, por ejemplo:
///
/// ```
/// flutter run \
///   --dart-define=SUPABASE_URL=https://ogrbbuwtsyezegkpwtsl.supabase.co \
///   --dart-define=SUPABASE_ANON_KEY=sb_publishable_Wv16MVxsTzA89lBeocarLQ_YL33Ya_E
/// ```
abstract final class SupabasePhoneCountryCodeConfig {
  static const baseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://ogrbbuwtsyezegkpwtsl.supabase.co',
  );
  static const apiKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_Wv16MVxsTzA89lBeocarLQ_YL33Ya_E',
  );

  static bool get isConfigured =>
      baseUrl.trim().isNotEmpty && apiKey.trim().isNotEmpty;
}
