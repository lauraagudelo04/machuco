import 'package:flutter_test/flutter_test.dart';
import 'package:machuco/controllers/auth/login_controller.dart';
import 'package:machuco/models/auth/registered_user.dart';
import 'package:machuco/service/auth/auth0_auth_service.dart';
import 'package:machuco/service/auth/hardcoded_auth_service.dart';
import 'package:machuco/service/auth/registered_user_directory.dart';
import 'package:machuco/service/auth/session_preferences.dart';
import 'package:machuco/service/storage/local_preferences_service.dart';

/// Fake de [AuthService] que usa credenciales hardcodeadas para tests.
class _TestAuthService implements AuthService {
  _TestAuthService();

  AuthSession? _session;

  @override
  Future<AuthSession?> restoreSession() async => _session;

  @override
  Future<AuthSession> login({required String email, required String password}) async {
    _session = AuthSession(
      userId: 'test-user-id',
      accessToken: 'test-token',
      idToken: 'test-id-token',
      name: 'Test Admin',
      email: email,
      role: RegisteredUserRole.admin,
    );
    return _session!;
  }

  @override
  Future<void> register({
    required String fullName,
    required String email,
    required String phoneNumber,
    required String password,
    required RegisteredUserRole role,
  }) async {}

  @override
  Future<AuthSession> loginWithGoogle({bool preferSignup = false}) async {
    _session = AuthSession(
      userId: 'test-user-id-google',
      accessToken: 'test-token',
      idToken: 'test-id-token',
      name: 'Google Admin',
      email: 'google@test.com',
      role: RegisteredUserRole.admin,
    );
    return _session!;
  }

  @override
  Future<void> requestPasswordReset({required String email}) async {}

  @override
  Future<void> logout() async {
    _session = null;
  }
}

/// Fake de [RegisteredUserDirectory] para tests.
class _TestUserDirectory implements RegisteredUserDirectory {
  _TestUserDirectory();

  final List<RegisteredUser> _users = [];

  @override
  Future<void> upsertUser(RegisteredUser user) async {
    _users.removeWhere((u) => u.email == user.email);
    _users.add(user);
  }

  @override
  Future<List<RegisteredUser>> listUsers({String? accessToken}) async => List.unmodifiable(_users);
}

/// Fake de [LocalPreferencesService] para tests.
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
  group('LoginController - persistencia de email de sesión', () {
    late _TestAuthService authService;
    late _TestUserDirectory userDirectory;
    late _FakeLocalPreferencesService fakePrefs;
    late SessionPreferences sessionPreferences;
    late LoginController controller;

    setUp(() {
      authService = _TestAuthService();
      userDirectory = _TestUserDirectory();
      fakePrefs = _FakeLocalPreferencesService(namespace: 'auth');
      sessionPreferences = SessionPreferences(preferences: fakePrefs);
      controller = LoginController(
        authService: authService,
        userDirectory: userDirectory,
        sessionPreferences: sessionPreferences,
      );
    });

    test('login guarda el email en SessionPreferences', () async {
      final session = await controller.login(
        email: 'admin@machuco.com',
        password: 'password123',
      );

      expect(session.email, 'admin@machuco.com');
      expect(await sessionPreferences.readEmail(), 'admin@machuco.com');
    });

    test('loginWithGoogle guarda el email en SessionPreferences', () async {
      final session = await controller.loginWithGoogle();

      expect(session.email, 'google@test.com');
      expect(await sessionPreferences.readEmail(), 'google@test.com');
    });

    test('restoreSession refresca el email guardado', () async {
      // Primero hacemos login para que haya sesión
      await controller.login(email: 'admin@machuco.com', password: 'password123');
      expect(await sessionPreferences.readEmail(), 'admin@machuco.com');

      // Simulamos que restoreSession devuelve una sesión distinta (p. ej. token renovado)
      authService._session = AuthSession(
        userId: 'test-user-id-2',
        accessToken: 'new-token',
        idToken: 'new-id-token',
        name: 'Test Admin',
        email: 'admin@machuco.com',
        role: RegisteredUserRole.admin,
      );

      final restored = await controller.restoreSession();

      expect(restored, isNotNull);
      expect(await sessionPreferences.readEmail(), 'admin@machuco.com');
    });

    test('logout borra el email guardado', () async {
      await controller.login(email: 'admin@machuco.com', password: 'password123');
      expect(await sessionPreferences.readEmail(), 'admin@machuco.com');

      await controller.logout();

      expect(await sessionPreferences.readEmail(), isNull);
      expect(controller.session, isNull);
    });

    test('logout sin sesión previa no falla', () async {
      // No hacemos login, solo logout
      await controller.logout();

      expect(await sessionPreferences.readEmail(), isNull);
      expect(controller.session, isNull);
    });

    test('sesión hardcodeada (HardcodedAuthService) también guarda email', () async {
      final hardcodedController = LoginController(
        authService: HardcodedAuthService(),
        sessionPreferences: sessionPreferences,
      );

      // Usar credenciales hardcodeadas válidas para admin
      final session = await hardcodedController.login(
        email: 'admin.test@machuco.com',
        password: 'AdminTest12345',
      );

      expect(session.email, 'admin.test@machuco.com');
      expect(await sessionPreferences.readEmail(), 'admin.test@machuco.com');
    });
  });
}