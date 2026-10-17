import 'package:flutter_test/flutter_test.dart';
import 'package:machuco/service/auth/session_preferences.dart';
import 'package:machuco/service/storage/local_preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Fake de [LocalPreferencesService] para tests que no dependan de shared_preferences.
class _FakeLocalPreferencesService implements LocalPreferencesService {
  _FakeLocalPreferencesService({required this.namespace});

  @override
  final String namespace;

  final Map<String, Object?> _data = {};

  String _fullKey(String key) => '$namespace.$key';

  @override
  Future<String?> getString(String key) async => _data[_fullKey(key)] as String?;

  @override
  Future<void> setString(String key, String value) async {
    _data[_fullKey(key)] = value;
  }

  @override
  Future<bool?> getBool(String key) async => _data[_fullKey(key)] as bool?;

  @override
  Future<void> setBool(String key, bool value) async {
    _data[_fullKey(key)] = value;
  }

  @override
  Future<int?> getInt(String key) async => _data[_fullKey(key)] as int?;

  @override
  Future<void> setInt(String key, int value) async {
    _data[_fullKey(key)] = value;
  }

  @override
  Future<double?> getDouble(String key) async => _data[_fullKey(key)] as double?;

  @override
  Future<void> setDouble(String key, double value) async {
    _data[_fullKey(key)] = value;
  }

  @override
  Future<List<String>?> getStringList(String key) async =>
      _data[_fullKey(key)] as List<String>?;

  @override
  Future<void> setStringList(String key, List<String> value) async {
    _data[_fullKey(key)] = value;
  }

  @override
  Future<bool> containsKey(String key) async =>
      _data.containsKey(_fullKey(key));

  @override
  Future<void> remove(String key) async {
    _data.remove(_fullKey(key));
  }

  @override
  Future<void> clear() async {
    final ownKeys = _data.keys.where((k) => k.startsWith('$namespace.')).toList();
    for (final k in ownKeys) {
      _data.remove(k);
    }
  }
}

void main() {
  group('SessionPreferences', () {
    test('guarda y lee el correo con el namespace auth', () async {
      final fake = _FakeLocalPreferencesService(namespace: 'auth');
      final prefs = SessionPreferences(preferences: fake);

      await prefs.saveEmail('admin@machuco.com');
      expect(await prefs.readEmail(), 'admin@machuco.com');
    });

    test('devuelve null cuando no hay correo guardado', () async {
      final fake = _FakeLocalPreferencesService(namespace: 'auth');
      final prefs = SessionPreferences(preferences: fake);

      expect(await prefs.readEmail(), isNull);
    });

    test('forgetEmail borra solo la clave de email', () async {
      final fake = _FakeLocalPreferencesService(namespace: 'auth');
      final prefs = SessionPreferences(preferences: fake);

      await prefs.saveEmail('admin@machuco.com');
      await prefs.forgetEmail();

      expect(await prefs.readEmail(), isNull);
      expect(await fake.containsKey('sessionEmail'), isFalse);
    });

    test('no borra claves de otros namespaces al llamar forgetEmail', () async {
      final fake = _FakeLocalPreferencesService(namespace: 'auth');
      // Simulamos que otro módulo (p. ej. bookings) tiene su propia clave
      fake._data['bookings.lastFilterMotelId'] = 'motel-1';

      final prefs = SessionPreferences(preferences: fake);
      await prefs.forgetEmail();

      expect(fake._data.containsKey('bookings.lastFilterMotelId'), isTrue);
    });

    test('usa SharedPreferencesLocalService real con mock inicial', () async {
      SharedPreferences.setMockInitialValues({'auth.sessionEmail': 'test@test.com'});

      final prefs = SessionPreferences();

      expect(await prefs.readEmail(), 'test@test.com');
    });

    test('saveEmail sobrescribe valor previo', () async {
      final fake = _FakeLocalPreferencesService(namespace: 'auth');
      final prefs = SessionPreferences(preferences: fake);

      await prefs.saveEmail('old@test.com');
      await prefs.saveEmail('new@test.com');

      expect(await prefs.readEmail(), 'new@test.com');
    });
  });
}