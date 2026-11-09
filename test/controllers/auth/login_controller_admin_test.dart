import 'package:flutter_test/flutter_test.dart';
import 'package:machuco/controllers/auth/auth_routes.dart';
import 'package:machuco/controllers/auth/login_controller.dart';
import 'package:machuco/models/auth/account_status.dart';
import 'package:machuco/models/auth/registered_user.dart';
import 'package:machuco/models/auth/registration_data.dart';
import 'package:machuco/models/auth/user_profile.dart';
import 'package:machuco/routes/routes.dart';
import 'package:machuco/service/auth/auth_preferences.dart';
import 'package:machuco/service/auth/auth_service.dart';
import 'package:machuco/service/storage/shared_preferences_local_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

AuthSession _session({
  RegisteredUserRole role = RegisteredUserRole.admin,
  AccountStatus status = AccountStatus.active,
  bool mustChangePassword = false,
  String email = 'ana@example.com',
}) => AuthSession(
  userId: 'u1',
  name: 'Ana',
  email: email,
  role: role,
  accessToken: 'a',
  idToken: 'b',
  accountStatus: status,
  profile: UserProfile(
    uid: 'u1',
    fullName: 'Ana',
    email: email,
    phoneNumber: '+573001234567',
    role: role,
    accountStatus: status,
    mustChangePassword: mustChangePassword,
  ),
);

void main() {
  late AuthPreferences preferences;
  late _FakeAuthService auth;
  late LoginController controller;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    preferences = AuthPreferences(
      preferences: SharedPreferencesLocalService(namespace: 'auth'),
    );
    auth = _FakeAuthService();
    controller = LoginController(authService: auth, preferences: preferences);
  });

  group('ruta tras iniciar sesión', () {
    test('admin con contraseña temporal va a cambiarla', () {
      expect(
        controller.resolvePostLoginRoute(_session(mustChangePassword: true)),
        AuthRoutes.adminChangePassword,
      );
    });

    test('admin sin marca, cliente y propietario siguen su ruta', () {
      expect(
        controller.resolvePostLoginRoute(_session()),
        AppRoutes.ownerManagement,
      );
      expect(
        controller.resolvePostLoginRoute(
          _session(role: RegisteredUserRole.client),
        ),
        AppRoutes.clientMotels,
      );
      expect(
        controller.resolvePostLoginRoute(
          _session(
            role: RegisteredUserRole.owner,
            status: AccountStatus.pendingApproval,
          ),
        ),
        AuthRoutes.accountReview,
      );
    });

    test('la marca solo aplica a administradores', () {
      expect(
        controller.resolvePostLoginRoute(
          _session(role: RegisteredUserRole.client, mustChangePassword: true),
        ),
        AppRoutes.clientMotels,
      );
    });
  });

  group('cuenta anonimizada', () {
    test(
      'un ingreso bloqueado limpia el perfil local y no guarda el correo',
      () async {
        auth.loginFailure = const AuthFailure(
          AuthFailureType.accountDeleted,
          'Esta cuenta ya no existe.',
        );

        await expectLater(
          controller.login(email: 'ana@example.com', password: 'x'),
          throwsA(
            isA<AuthFailure>().having(
              (f) => f.type,
              'type',
              AuthFailureType.accountDeleted,
            ),
          ),
        );

        expect(controller.session, isNull);
        expect(await preferences.loadCurrentUserEmail(), isNull);
      },
    );

    test('restaurar una sesión anonimizada la descarta', () async {
      await preferences.saveCurrentUserEmail('ana@example.com');
      auth.restored = _session(status: AccountStatus.anonymized);

      final restored = await controller.restoreSession();

      expect(restored, isNull);
      expect(await preferences.loadCurrentUserEmail(), isNull);
    });
  });

  group('Recordar mi correo', () {
    test('sin nada guardado: casilla desmarcada y sin correo', () async {
      final state = await controller.loadRememberedEmail();
      expect(state.remember, isFalse);
      expect(state.email, isNull);
    });

    test(
      'marcada: guarda el correo normalizado y se precarga después',
      () async {
        await controller.login(
          email: '  Ana@Example.COM ',
          password: 'x',
          rememberEmail: true,
        );

        final state = await LoginController(
          authService: auth,
          preferences: preferences,
        ).loadRememberedEmail();
        expect(state.remember, isTrue);
        expect(state.email, 'ana@example.com');
      },
    );

    test('desmarcada: elimina el correo recordado', () async {
      await controller.login(
        email: 'ana@example.com',
        password: 'x',
        rememberEmail: true,
      );
      await controller.login(
        email: 'ana@example.com',
        password: 'x',
        rememberEmail: false,
      );

      final state = await controller.loadRememberedEmail();
      expect(state.remember, isFalse);
      expect(state.email, isNull);
    });

    test('por omisión no recuerda nada', () async {
      await controller.login(email: 'ana@example.com', password: 'x');
      expect((await controller.loadRememberedEmail()).email, isNull);
    });

    test('un ingreso fallido no cambia lo recordado', () async {
      await controller.login(
        email: 'ana@example.com',
        password: 'x',
        rememberEmail: true,
      );
      auth.loginFailure = const AuthFailure(
        AuthFailureType.invalidCredentials,
        'Correo o contraseña incorrectos.',
      );

      await expectLater(
        controller.login(
          email: 'otro@example.com',
          password: 'mala',
          rememberEmail: false,
        ),
        throwsA(isA<AuthFailure>()),
      );

      final state = await controller.loadRememberedEmail();
      expect(state.remember, isTrue);
      expect(state.email, 'ana@example.com');
    });

    test(
      'cerrar sesión conserva el correo recordado, pero no el de sesión',
      () async {
        await controller.login(
          email: 'ana@example.com',
          password: 'x',
          rememberEmail: true,
        );

        await controller.logout();

        expect(await preferences.loadCurrentUserEmail(), isNull);
        final state = await controller.loadRememberedEmail();
        expect(state.remember, isTrue);
        expect(state.email, 'ana@example.com');
      },
    );

    test('eliminar la cuenta borra el correo recordado', () async {
      await controller.login(
        email: 'ana@example.com',
        password: 'x',
        rememberEmail: true,
      );

      await controller.deleteAccount(
        password: 'secreto123',
        confirmationText: LoginController.deleteConfirmationText,
      );

      final state = await controller.loadRememberedEmail();
      expect(state.remember, isFalse);
      expect(state.email, isNull);
    });

    test('sin preferencias no falla', () async {
      final bare = LoginController(authService: auth);
      expect((await bare.loadRememberedEmail()).remember, isFalse);
      await bare.login(
        email: 'ana@example.com',
        password: 'x',
        rememberEmail: true,
      );
    });

    test('un correo vacío o solo espacios no se recuerda', () async {
      await preferences.saveRememberedEmail('   ');
      final state = await preferences.loadRememberedEmail();
      expect(state.remember, isFalse);
      expect(state.email, isNull);
    });
  });
}

final class _FakeAuthService implements AuthService {
  AuthFailure? loginFailure;
  AuthSession? restored;

  @override
  Future<AuthSession?> restoreSession() async => restored;

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    final failure = loginFailure;
    if (failure != null) throw failure;
    return _session(role: RegisteredUserRole.client, email: email);
  }

  @override
  Future<AuthSession> loginWithGoogle({bool preferSignup = false}) async =>
      _session();

  @override
  Future<void> register({
    required String fullName,
    required String email,
    required String phoneNumber,
    required String password,
    required RegisteredUserRole role,
  }) async {}

  @override
  Future<void> registerAccount(RegistrationData data) async {}

  @override
  Future<void> requestPasswordReset({required String email}) async {}

  @override
  Future<void> logout() async {}

  @override
  Future<void> deleteAccount({required String password}) async {}
}
