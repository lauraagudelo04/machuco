import 'package:machuco/service/storage/local_preferences_service.dart';
import 'package:machuco/service/storage/shared_preferences_local_service.dart';

/// Preferencias locales no sensibles del módulo de propietarios
/// (namespace `owners`).
///
/// Guarda el último indicativo usado en el formulario para preseleccionarlo la
/// próxima vez. El correo del administrador **no** se guarda aquí: se lee con
/// `AuthPreferences().loadCurrentUserEmail()`, que es la fuente única de la
/// sesión.
class OwnerPreferences {
  OwnerPreferences({LocalPreferencesService? preferences})
    : _preferences =
          preferences ?? SharedPreferencesLocalService(namespace: namespace);

  static const namespace = 'owners';

  static const _lastCountryCodeIdKey = 'lastCountryCodeId';

  final LocalPreferencesService _preferences;

  /// Id del indicativo elegido la última vez, o `null` si aún no hay ninguno.
  Future<int?> loadLastCountryCodeId() =>
      _preferences.getInt(_lastCountryCodeIdKey);

  Future<void> saveLastCountryCodeId(int id) =>
      _preferences.setInt(_lastCountryCodeIdKey, id);
}
