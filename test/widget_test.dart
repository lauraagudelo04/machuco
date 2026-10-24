import 'package:flutter_test/flutter_test.dart';
import 'package:machuco/controllers/auth/login_controller.dart';
import 'package:machuco/main.dart';
import 'package:machuco/models/auth/registered_user.dart';
import 'package:machuco/routes/routes.dart';
import 'package:machuco/service/auth/auth0_auth_service.dart';
import 'package:machuco/service/auth/hardcoded_auth_service.dart';
import 'package:machuco/service/auth/registered_user_directory.dart';

void main() {
  testWidgets('muestra la pantalla de inicio de sesión', (tester) async {
    await tester.pumpWidget(const MachucoApp());
    await tester.pump();

    expect(find.text('Machuco'), findsOneWidget);
    expect(find.text('Inicia sesión o crea tu cuenta'), findsOneWidget);
  });

  test('guarda el rol seleccionado al registrar', () async {
    final auth = _FakeAuthService();
    final directory = _FakeRegisteredUserDirectory();
    final controller = LoginController(
      authService: auth,
      userDirectory: directory,
    );

    await controller.register(
      fullName: 'Ana Perez',
      email: 'ana@example.com',
      phoneNumber: '+573001234567',
      password: 'SecurePassword12345',
      role: RegisteredUserRole.owner,
    );

    expect(auth.registerRole, RegisteredUserRole.owner);
    expect(directory.users, hasLength(1));
    expect(directory.users.first.role, RegisteredUserRole.owner);
  });

  test('redirige a la ruta correcta por rol', () {
    final controller = LoginController(
      authService: _FakeAuthService(),
      userDirectory: _FakeRegisteredUserDirectory(),
    );

    expect(
      controller.resolveRouteByRole(RegisteredUserRole.client),
      AppRoutes.clientMotels,
    );
    expect(
      controller.resolveRouteByRole(RegisteredUserRole.owner),
      AppRoutes.ownerMotels,
    );
    expect(
      controller.resolveRouteByRole(RegisteredUserRole.admin),
      AppRoutes.ownerManagement,
    );
  });

  test('logout limpia sesión en controller y llama auth logout', () async {
    final auth = _FakeAuthService();
    final controller = LoginController(
      authService: auth,
      userDirectory: _FakeRegisteredUserDirectory(),
    );

    await controller.login(email: 'owner@example.com', password: 'password');
    expect(controller.session, isNotNull);

    await controller.logout();
    expect(auth.logoutCalled, isTrue);
    expect(controller.session, isNull);
  });

  test('usuarios quemados redirigen a la ruta correcta por rol', () async {
    final controller = LoginController(
      authService: HardcodedAuthService(),
      userDirectory: _FakeRegisteredUserDirectory(),
    );

    final expectations = <({HardcodedAuthUser user, String route})>[
      (
        user: hardcodedAuthUsers.firstWhere(
          (candidate) => candidate.role == RegisteredUserRole.client,
        ),
        route: AppRoutes.clientMotels,
      ),
      (
        user: hardcodedAuthUsers.firstWhere(
          (candidate) => candidate.role == RegisteredUserRole.owner,
        ),
        route: AppRoutes.ownerMotels,
      ),
      (
        user: hardcodedAuthUsers.firstWhere(
          (candidate) => candidate.role == RegisteredUserRole.admin,
        ),
        route: AppRoutes.ownerManagement,
      ),
    ];

    for (final item in expectations) {
      final session = await controller.login(
        email: item.user.email,
        password: item.user.password,
      );
      expect(controller.resolvePostLoginRoute(session), item.route);
      await controller.logout();
    }
  });
}

final class _FakeAuthService implements AuthService {
  RegisteredUserRole? registerRole;
  bool logoutCalled = false;

  @override
  Future<AuthSession?> restoreSession() async => null;

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    return AuthSession(
      userId: 'user-1',
      name: 'Test User',
      email: 'test@example.com',
      role: RegisteredUserRole.client,
      accessToken: 'access',
      idToken: 'header.payload.signature',
    );
  }

  @override
  Future<AuthSession> loginWithGoogle({bool preferSignup = false}) async {
    return const AuthSession(
      userId: 'user-2',
      name: 'Google User',
      email: 'google@example.com',
      role: RegisteredUserRole.client,
      accessToken: 'access',
      idToken: 'header.payload.signature',
    );
  }

  @override
  Future<void> register({
    required String fullName,
    required String email,
    required String phoneNumber,
    required String password,
    required RegisteredUserRole role,
  }) async {
    registerRole = role;
  }

  @override
  Future<void> requestPasswordReset({required String email}) async {}

  @override
  Future<void> logout() async {
    logoutCalled = true;
  }
}

final class _FakeRegisteredUserDirectory implements RegisteredUserDirectory {
  final List<RegisteredUser> users = <RegisteredUser>[];

  @override
  Future<List<RegisteredUser>> listUsers({String? accessToken}) async => users;

  @override
  Future<void> upsertUser(RegisteredUser user) async {
    final index = users.indexWhere(
      (candidate) => candidate.email.toLowerCase() == user.email.toLowerCase(),
    );
    if (index == -1) {
      users.add(user);
      return;
    }
    users[index] = user;
  }
}
