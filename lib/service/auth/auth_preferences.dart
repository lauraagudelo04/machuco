import 'package:machuco/service/storage/local_preferences_service.dart';
import 'package:machuco/service/storage/shared_preferences_local_service.dart';

/// Preferencias locales no sensibles del módulo de autenticación
/// (namespace `auth`).
///
/// Es la API pública para que otras funcionalidades (perfil, reservas, PQRS,
/// pagos) lean el correo del usuario autenticado sin conocer las claves:
///
/// ```dart
/// final email = await AuthPreferences().loadCurrentUserEmail();
/// ```
///
/// El correo sirve para mostrar y precargar datos, **nunca para autorizar**:
/// la autorización se valida con la sesión en el backend. Aquí no se guardan
/// contraseñas, tokens ni el NIT.
class AuthPreferences {
  AuthPreferences({LocalPreferencesService? preferences})
    : _preferences =
          preferences ?? SharedPreferencesLocalService(namespace: namespace);

  static const namespace = 'auth';

  static const _currentUserEmailKey = 'currentUserEmail';
  static const _lastCountryCodeIdKey = 'lastCountryCodeId';
  static const _catalogsSyncedAtKey = 'catalogsSyncedAt';

  final LocalPreferencesService _preferences;

  /// Normaliza el correo antes de guardarlo: sin espacios y en minúsculas.
  static String normalizeEmail(String email) => email.trim().toLowerCase();

  /// Correo del usuario autenticado, o `null` si no hay ninguno guardado.
  Future<String?> loadCurrentUserEmail() async {
    final email = await _preferences.getString(_currentUserEmailKey);
    if (email == null || email.trim().isEmpty) return null;
    return email;
  }

  Future<void> saveCurrentUserEmail(String email) async {
    final normalized = normalizeEmail(email);
    if (normalized.isEmpty) {
      await clearCurrentUserEmail();
      return;
    }
    await _preferences.setString(_currentUserEmailKey, normalized);
  }

  Future<void> clearCurrentUserEmail() =>
      _preferences.remove(_currentUserEmailKey);

  Future<int?> loadLastCountryCodeId() =>
      _preferences.getInt(_lastCountryCodeIdKey);

  Future<void> saveLastCountryCodeId(int id) =>
      _preferences.setInt(_lastCountryCodeIdKey, id);

  /// Momento de la última sincronización de maestros con Supabase.
  Future<DateTime?> loadCatalogsSyncedAt() async {
    final raw = await _preferences.getString(_catalogsSyncedAtKey);
    return raw == null ? null : DateTime.tryParse(raw);
  }

  Future<void> saveCatalogsSyncedAt(DateTime value) => _preferences.setString(
    _catalogsSyncedAtKey,
    value.toUtc().toIso8601String(),
  );
}
