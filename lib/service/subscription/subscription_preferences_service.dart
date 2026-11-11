import 'package:machuco/service/auth/auth_preferences.dart';

class SubscriptionPreferencesService {
  SubscriptionPreferencesService({AuthPreferences? preferences})
    : _preferences = preferences ?? AuthPreferences();

  final AuthPreferences _preferences;

  /// Lee el correo de la sesión guardado por el módulo de autenticación.
  /// Sin correo no se consulta una suscripción de prueba ni la de otro usuario.
  Future<String?> getUserEmail() async {
    final email = await _preferences.loadCurrentUserEmail();
    if (email == null) return null;
    final normalized = email.trim().toLowerCase();
    return normalized.isEmpty ? null : normalized;
  }
}
