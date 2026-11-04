import 'package:shared_preferences/shared_preferences.dart';

import 'local_preferences_service.dart';

/// Implementación de [LocalPreferencesService] sobre `shared_preferences`,
/// usando la API clásica (`SharedPreferences.getInstance()`). Por acuerdo del
/// equipo no se usan `SharedPreferencesAsync` ni `SharedPreferencesWithCache`.
///
/// Es la única clase del proyecto que importa `shared_preferences`.
///
/// ```dart
/// final preferences = SharedPreferencesLocalService(namespace: 'bookings');
/// await preferences.setString('lastFilterMotelId', motel.id);
/// final lastMotelId = await preferences.getString('lastFilterMotelId');
/// ```
class SharedPreferencesLocalService implements LocalPreferencesService {
  /// [namespace] y cada clave deben ir en `lowerCamelCase`, sin puntos.
  ///
  /// [preferences] permite inyectar una instancia ya obtenida; si se omite,
  /// se usa el singleton de `SharedPreferences.getInstance()` la primera vez
  /// que se lee o escribe (no en el constructor), así la clase puede crearse
  /// antes de que Flutter termine de inicializar los plugins.
  SharedPreferencesLocalService({
    required String namespace,
    SharedPreferences? preferences,
  }) : namespace = _checkName(namespace, 'namespace'),
       _injectedPreferences = preferences;

  @override
  final String namespace;

  final SharedPreferences? _injectedPreferences;

  static final _namePattern = RegExp(r'^[a-z][a-zA-Z0-9]*$');

  static String _checkName(String value, String name) {
    if (!_namePattern.hasMatch(value)) {
      throw ArgumentError.value(
        value,
        name,
        'Debe estar en lowerCamelCase y sin puntos',
      );
    }
    return value;
  }

  Future<SharedPreferences> get _preferences async =>
      _injectedPreferences ?? await SharedPreferences.getInstance();

  String _key(String key) => '$namespace.${_checkName(key, 'key')}';

  @override
  Future<String?> getString(String key) async =>
      (await _preferences).getString(_key(key));

  @override
  Future<void> setString(String key, String value) async {
    await (await _preferences).setString(_key(key), value);
  }

  @override
  Future<bool?> getBool(String key) async =>
      (await _preferences).getBool(_key(key));

  @override
  Future<void> setBool(String key, bool value) async {
    await (await _preferences).setBool(_key(key), value);
  }

  @override
  Future<int?> getInt(String key) async =>
      (await _preferences).getInt(_key(key));

  @override
  Future<void> setInt(String key, int value) async {
    await (await _preferences).setInt(_key(key), value);
  }

  @override
  Future<double?> getDouble(String key) async =>
      (await _preferences).getDouble(_key(key));

  @override
  Future<void> setDouble(String key, double value) async {
    await (await _preferences).setDouble(_key(key), value);
  }

  @override
  Future<List<String>?> getStringList(String key) async =>
      (await _preferences).getStringList(_key(key));

  @override
  Future<void> setStringList(String key, List<String> value) async {
    await (await _preferences).setStringList(_key(key), value);
  }

  @override
  Future<bool> containsKey(String key) async =>
      (await _preferences).containsKey(_key(key));

  @override
  Future<void> remove(String key) async {
    await (await _preferences).remove(_key(key));
  }

  @override
  Future<void> clear() async {
    final preferences = await _preferences;
    final ownKeys = preferences
        .getKeys()
        .where((key) => key.startsWith('$namespace.'))
        .toList();
    for (final key in ownKeys) {
      await preferences.remove(key);
    }
  }
}
