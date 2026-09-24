/// Contrato para persistir preferencias locales simples (clave-valor) del
/// dispositivo, independiente del origen de datos concreto.
///
/// Ninguna vista ni controlador debe importar `shared_preferences`
/// directamente: deben depender de esta interfaz, igual que
/// `RegisteredUserDirectory` en `lib/service/auth/`. Ver
/// `docs/shared_preferences.md` para el contexto completo de esta decisión.
abstract class LocalPreferencesService {
  /// Último motel usado para filtrar una lista de reservas.
  Future<String?> getLastFilterMotelId();

  Future<void> setLastFilterMotelId(String motelId);

  Future<void> clearLastFilterMotelId();
}
