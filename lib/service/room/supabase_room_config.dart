/// Configuración inyectada con `--dart-define`; no almacena secretos en Git.
abstract final class SupabaseRoomConfig {
  static const baseUrl = String.fromEnvironment('SUPABASE_URL');
  static const apiKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static bool get isConfigured =>
      baseUrl.trim().isNotEmpty && apiKey.trim().isNotEmpty;
}
