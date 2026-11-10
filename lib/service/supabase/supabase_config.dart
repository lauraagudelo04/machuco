/// Configuración pública compartida por los catálogos y moteles.
/// Los valores se pueden sobrescribir mediante `--dart-define`.
abstract final class SupabaseConfig {
  static const baseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://ogrbbuwtsyezegkpwtsl.supabase.co',
  );
  static const apiKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: String.fromEnvironment(
      'SUPABASE_PUBLISHABLE_KEY',
      defaultValue: 'sb_publishable_Wv16MVxsTzA89lBeocarLQ_YL33Ya_E',
    ),
  );

  static bool get isConfigured =>
      baseUrl.trim().isNotEmpty && apiKey.trim().isNotEmpty;
}
