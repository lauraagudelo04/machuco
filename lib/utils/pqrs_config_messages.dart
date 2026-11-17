import 'package:machuco/models/pqrs/pqrs_config_result.dart';
import 'package:machuco/service/supabase/supabase_json_reader.dart';

/// User-facing messages (Spanish) for the PQRS configuration fallbacks.
/// Centralized so the formats, settings and types repositories say the same.
String pqrsConfigFallbackMessage(
  SupabaseReadFailure failure,
  PqrsConfigSource usedSource,
) {
  final used = usedSource == PqrsConfigSource.cache
      ? 'Se usan los datos guardados en este dispositivo.'
      : 'Se usan los valores predeterminados.';
  final reason = switch (failure) {
    SupabaseReadFailure.connection =>
      'No hay conexión para actualizar la configuración de PQRS.',
    SupabaseReadFailure.permission =>
      'No tienes permiso para consultar la configuración de PQRS.',
    SupabaseReadFailure.notConfigured =>
      'La configuración de PQRS no está disponible en esta instalación.',
    SupabaseReadFailure.server || SupabaseReadFailure.invalidResponse =>
      'No fue posible actualizar la configuración de PQRS.',
  };
  return '$reason $used';
}
