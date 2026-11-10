import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:machuco/controllers/auth/login_controller.dart';
import 'package:machuco/core/design_system/design_system.dart';
import 'package:machuco/models/auth/registered_user.dart';
import 'package:machuco/models/auth/registration_data.dart';
import 'package:machuco/routes/routes.dart';
import 'package:machuco/service/auth/auth_service.dart';
import 'package:machuco/service/auth/registered_user_directory.dart';
import 'package:machuco/views/login/login_page.dart';

void main() {
  testWidgets('muestra la pantalla de inicio de sesión', (tester) async {
    // Se inyecta un servicio falso: las pruebas no dependen de Firebase real.
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: LoginPage(authService: _FakeAuthService()),
      ),
    );
    await tester.pump();

    expect(find.text('Machuco'), findsOneWidget);
    expect(find.text('Inicia sesión o crea tu cuenta'), findsOneWidget);
  });

  testWidgets('el registro se dibuja sin errores y no ofrece Administrador', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(412, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: LoginPage(
          authService: _FakeAuthService(),
          initialTab: AuthTab.register,
        ),
      ),
    );
    await tester.pump();

    // Un InputDecorator sin ancho dentro de un Row dejaba la vista en blanco.
    expect(tester.takeException(), isNull);
    expect(find.text('Cliente'), findsOneWidget);
    expect(find.text('Propietario'), findsOneWidget);
    expect(find.text('Administrador'), findsNothing);
  });

  testWidgets('el login ofrece Google y GitHub sin "Próximamente"', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: LoginPage(authService: _FakeAuthService()),
      ),
    );
    await tester.pump();

    expect(find.text('Próximamente'), findsNothing);
    expect(find.text('Continuar con Google'), findsOneWidget);
    expect(find.text('Continuar con GitHub'), findsOneWidget);
  });

  test('guarda el rol seleccionado al registrar', () async {
    final auth = _FakeAuthService();
    final controller = LoginController(authService: auth);

    await controller.register(
      fullName: 'Ana Perez',
      email: 'ana@example.com',
      phoneNumber: '+573001234567',
      password: 'SecurePassword12345',
      role: RegisteredUserRole.owner,
    );

    expect(auth.registerRole, RegisteredUserRole.owner);
    // La persistencia del perfil la hace el AuthService (Firestore).
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

  test('cada rol autenticado redirige a su ruta inicial', () async {
    final expectations = <RegisteredUserRole, String>{
      RegisteredUserRole.client: AppRoutes.clientMotels,
      RegisteredUserRole.owner: AppRoutes.ownerMotels,
      RegisteredUserRole.admin: AppRoutes.ownerManagement,
    };

    for (final entry in expectations.entries) {
      final controller = LoginController(
        authService: _FakeAuthService(loginRole: entry.key),
        userDirectory: _FakeRegisteredUserDirectory(),
      );
      final session = await controller.login(
        email: 'usuario@example.com',
        password: 'password123',
      );
      expect(controller.resolvePostLoginRoute(session), entry.value);
    }
  });
}

final class _FakeAuthService implements AuthService {
  _FakeAuthService({this.loginRole = RegisteredUserRole.client});

  final RegisteredUserRole loginRole;
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
      role: loginRole,
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
  Future<void> registerAccount(RegistrationData data) async {}

  @override
  Future<void> deleteAccount({required String password}) async {}

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
