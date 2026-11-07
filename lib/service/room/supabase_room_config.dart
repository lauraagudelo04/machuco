/// Configuración del proyecto Supabase usada por habitaciones y catálogos de
/// autenticación.
///
/// Los valores por defecto corresponden al proyecto de desarrollo y permiten
/// ejecutar la app con `flutter run` sin argumentos. Se pueden sobrescribir en
/// tiempo de compilación:
///
/// ```
/// flutter run \
///   --dart-define=SUPABASE_URL=https://<proyecto>.supabase.co \
///   --dart-define=SUPABASE_ANON_KEY=<clave-publica>
/// ```
///
/// La clave publicable no es `service_role` y no reemplaza las políticas RLS.
abstract final class SupabaseRoomConfig {
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
