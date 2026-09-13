import 'package:machuco/models/auth/registered_user.dart';
import 'package:machuco/service/auth/auth0_auth_service.dart';

final class HardcodedAuthUser {
  const HardcodedAuthUser({
    required this.email,
    required this.password,
    required this.name,
    required this.role,
  });

  final String email;
  final String password;
  final String name;
  final RegisteredUserRole role;
}

const List<HardcodedAuthUser> hardcodedAuthUsers = <HardcodedAuthUser>[
  HardcodedAuthUser(
    email: 'cliente.test@machuco.com',
    password: 'ClienteTest12345',
    name: 'Cliente Test MACHUCO',
    role: RegisteredUserRole.client,
  ),
  HardcodedAuthUser(
    email: 'propietario.test@machuco.com',
    password: 'PropietarioTest12345',
    name: 'Propietario Test MACHUCO',
    role: RegisteredUserRole.owner,
  ),
  HardcodedAuthUser(
    email: 'admin.test@machuco.com',
    password: 'AdminTest12345',
    name: 'Admin Test MACHUCO',
    role: RegisteredUserRole.admin,
  ),
];

/// Servicio de autenticación local para pruebas de login por rol.
///
/// No depende de Auth0 ni persiste credenciales fuera del ciclo de ejecución.
final class HardcodedAuthService implements AuthService {
  AuthSession? _activeSession;

  @override
  Future<AuthSession?> restoreSession() async => _activeSession;

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    HardcodedAuthUser? user;
    for (final candidate in hardcodedAuthUsers) {
      if (candidate.email.toLowerCase() == normalizedEmail &&
          candidate.password == password) {
        user = candidate;
        break;
      }
    }

    if (user == null) {
      throw const AuthFailure(
        AuthFailureType.invalidCredentials,
        'Correo o contraseña incorrectos.',
      );
    }

    final session = AuthSession(
      userId: 'hardcoded-${user.role.metadataValue}',
      name: user.name,
      email: user.email,
      role: user.role,
      accessToken: 'hardcoded-access-token',
      idToken: 'hardcoded-id-token',
    );
    _activeSession = session;
    return session;
  }

  @override
  Future<AuthSession> loginWithGoogle({bool preferSignup = false}) async {
    throw const AuthFailure(
      AuthFailureType.invalidConfiguration,
      'El login con Google no está disponible en modo de usuarios de prueba.',
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
    throw const AuthFailure(
      AuthFailureType.invalidConfiguration,
      'El registro está deshabilitado en modo de usuarios de prueba.',
    );
  }

  @override
  Future<void> requestPasswordReset({required String email}) async {
    throw const AuthFailure(
      AuthFailureType.invalidConfiguration,
      'La recuperación de contraseña no está disponible en modo de pruebas.',
    );
  }

  @override
  Future<void> logout() async {
    _activeSession = null;
  }
}
