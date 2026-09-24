/// Contrato transversal para persistir preferencias locales simples
/// (clave-valor, no sensibles) del dispositivo, independiente del origen de
/// datos concreto.
///
/// Es genérico a propósito: no conoce ninguna funcionalidad concreta. Cada
/// módulo crea su propia instancia con un [namespace] propio (por ejemplo
/// `bookings`, `pqrs`, `payments`) y define sus claves localmente, así ninguna
/// rama tiene que editar un archivo compartido para agregar una preferencia.
///
/// El namespace identifica la **funcionalidad**, nunca a la persona ni a la
/// rama: la misma preferencia debe seguir funcionando cuando otra persona
/// herede el módulo.
///
/// Ninguna vista ni controlador debe importar `shared_preferences`
/// directamente: deben depender de esta interfaz, igual que
/// `RegisteredUserDirectory` en `lib/service/auth/`. Ver
/// `docs/shared_preferences.md` para el contexto completo de esta decisión.
abstract class LocalPreferencesService {
  /// Prefijo de todas las claves de esta instancia (`<namespace>.<key>`).
  String get namespace;

  Future<String?> getString(String key);

  Future<void> setString(String key, String value);

  Future<bool?> getBool(String key);

  Future<void> setBool(String key, bool value);

  Future<int?> getInt(String key);

  Future<void> setInt(String key, int value);

  Future<double?> getDouble(String key);

  Future<void> setDouble(String key, double value);

  Future<List<String>?> getStringList(String key);

  Future<void> setStringList(String key, List<String> value);

  Future<bool> containsKey(String key);

  Future<void> remove(String key);

  /// Elimina solo las claves de este [namespace]; no toca las de otros
  /// módulos.
  Future<void> clear();
}
