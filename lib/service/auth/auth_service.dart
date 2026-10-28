import 'package:machuco/models/auth/registered_user.dart';

/// Categorizes why an [AuthService] operation failed, so views can choose
/// an appropriate message or recovery action without parsing raw provider
/// error strings.
enum AuthFailureType {
  invalidCredentials,
  emailAlreadyExists,
  weakPassword,
  invalidConfiguration,
  network,
  cancelled,
  unknown,
}

/// An error thrown by any [AuthService] implementation.
///
/// [message] is already a user-safe, Spanish-language message suitable for
/// display; it must not leak raw provider error details.
final class AuthFailure implements Exception {
  const AuthFailure(this.type, this.message);

  final AuthFailureType type;
  final String message;
}

/// The authenticated session data the app keeps after a successful
/// [AuthService.login], [AuthService.loginWithGoogle] or
/// [AuthService.restoreSession].
final class AuthSession {
  const AuthSession({
    required this.userId,
    required this.name,
    required this.email,
    required this.role,
    required this.accessToken,
    required this.idToken,
  });

  final String userId;
  final String name;
  final String email;
  final RegisteredUserRole role;
  final String accessToken;
  final String idToken;
}

/// Contract for authenticating a user and managing their session.
///
/// Transitional: it only exists while `FirebaseAuthService` and the
/// temporary `HardcodedAuthService` (local test accounts, gated by
/// `AuthConfig.useHardcodedAuthUsers`) coexist. Do not extend it with new
/// capabilities; it is removed together with the hardcoded login.
abstract interface class AuthService {
  Future<AuthSession?> restoreSession();

  Future<AuthSession> login({required String email, required String password});

  Future<AuthSession> loginWithGoogle({bool preferSignup = false});

  Future<void> register({
    required String fullName,
    required String email,
    required String phoneNumber,
    required String password,
    required RegisteredUserRole role,
  });

  Future<void> requestPasswordReset({required String email});

  Future<void> logout();
}
