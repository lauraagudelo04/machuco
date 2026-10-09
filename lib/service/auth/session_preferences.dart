import 'package:machuco/service/storage/local_preferences_service.dart';
import 'package:machuco/service/storage/shared_preferences_local_service.dart';

/// Guarda y lee el correo de la sesión activa en preferencias locales.
///
/// Usa el namespace `auth` (p. ej. `auth.sessionEmail`).
/// Es la única clase del módulo de auth que conoce `SharedPreferencesLocalService`.
class SessionPreferences {
  SessionPreferences({LocalPreferencesService? preferences})
    : _preferences = preferences ?? SharedPreferencesLocalService(namespace: 'auth');

  final LocalPreferencesService _preferences;

  static const _emailKey = 'sessionEmail';

  /// Guarda el correo de la sesión activa.
  Future<void> saveEmail(String email) async {
    await _preferences.setString(_emailKey, email);
  }

  /// Lee el correo de la sesión activa, o `null` si no hay ninguno guardado.
  Future<String?> readEmail() async {
    return _preferences.getString(_emailKey);
  }

  /// Borra el correo guardado (p. ej. al cerrar sesión).
  Future<void> forgetEmail() async {
    await _preferences.remove(_emailKey);
  }
}