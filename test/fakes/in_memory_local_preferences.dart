import 'package:machuco/service/storage/local_preferences_service.dart';

/// In-memory [LocalPreferencesService] for tests. Set [failWrites] to simulate
/// a storage failure.
class InMemoryLocalPreferences implements LocalPreferencesService {
  InMemoryLocalPreferences({this.namespace = 'pqrs'});

  @override
  final String namespace;

  final Map<String, Object> values = {};
  bool failWrites = false;

  void _write(String key, Object value) {
    if (failWrites) throw Exception('write failed');
    values[key] = value;
  }

  @override
  Future<String?> getString(String key) async => values[key] as String?;

  @override
  Future<void> setString(String key, String value) async => _write(key, value);

  @override
  Future<bool?> getBool(String key) async => values[key] as bool?;

  @override
  Future<void> setBool(String key, bool value) async => _write(key, value);

  @override
  Future<int?> getInt(String key) async => values[key] as int?;

  @override
  Future<void> setInt(String key, int value) async => _write(key, value);

  @override
  Future<double?> getDouble(String key) async => values[key] as double?;

  @override
  Future<void> setDouble(String key, double value) async => _write(key, value);

  @override
  Future<List<String>?> getStringList(String key) async =>
      values[key] as List<String>?;

  @override
  Future<void> setStringList(String key, List<String> value) async =>
      _write(key, value);

  @override
  Future<bool> containsKey(String key) async => values.containsKey(key);

  @override
  Future<void> remove(String key) async => values.remove(key);

  @override
  Future<void> clear() async => values.clear();
}
