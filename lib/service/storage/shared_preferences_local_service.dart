import 'package:shared_preferences/shared_preferences.dart';

import 'local_preferences_service.dart';

/// Implementación de [LocalPreferencesService] sobre `shared_preferences`,
/// usando la API `SharedPreferencesAsync` (recomendada por el paquete desde
/// la versión 2.3.0 en lugar del singleton `getInstance()`).
class SharedPreferencesLocalService implements LocalPreferencesService {
  SharedPreferencesLocalService({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _preferences;

  static const _lastFilterMotelIdKey = 'bookings.lastFilterMotelId';

  @override
  Future<String?> getLastFilterMotelId() {
    return _preferences.getString(_lastFilterMotelIdKey);
  }

  @override
  Future<void> setLastFilterMotelId(String motelId) {
    return _preferences.setString(_lastFilterMotelIdKey, motelId);
  }

  @override
  Future<void> clearLastFilterMotelId() {
    return _preferences.remove(_lastFilterMotelIdKey);
  }
}
