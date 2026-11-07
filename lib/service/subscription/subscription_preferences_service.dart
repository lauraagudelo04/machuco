import 'package:machuco/service/storage/local_preferences_service.dart';
import 'package:machuco/service/storage/shared_preferences_local_service.dart';

class SubscriptionPreferencesService {
  SubscriptionPreferencesService({LocalPreferencesService? preferences})
    : _preferences =
          preferences ??
          SharedPreferencesLocalService(namespace: 'subscription');

  final LocalPreferencesService _preferences;

  /// Dummy temporal: adaptar namespace y clave cuando login publique su contrato.
  /// No escribe datos de sesión; solo el correo tiene un valor de prueba.
  Future<String> getUserEmail() async {
    final email = await _preferences.getString('userEmail');
    return email == null || email.trim().isEmpty
        ? 'propietario.test@machuco.com'
        : email.trim().toLowerCase();
  }
}
