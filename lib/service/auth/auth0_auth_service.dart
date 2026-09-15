import 'dart:convert';

import 'package:auth0_flutter/auth0_flutter.dart';
import 'package:machuco/models/auth/registered_user.dart';
import 'package:machuco/service/auth/auth0_config.dart';

/// Categorizes why an [AuthService] operation failed, so views can choose
/// an appropriate message or recovery action without parsing raw Auth0
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

/// Contract for authenticating a user and managing their session,
/// independent of the concrete provider.
///
/// Implemented today by [Auth0AuthService] (production) and
/// `HardcodedAuthService` (local/QA test accounts, gated by
/// [Auth0Config.useHardcodedAuthUsers]).
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

/// [AuthService] implementation backed by Auth0 via `auth0_flutter`.
///
/// Wraps the Auth0 database connection and Google social login, persists
/// credentials through Auth0's credentials manager, and derives the
/// [RegisteredUserRole] for a session from the ID token claims (see
/// [_extractRole]).
final class Auth0AuthService implements AuthService {
  Auth0AuthService._(this._auth0);

  final Auth0 _auth0;

  /// Builds an [Auth0AuthService] from `--dart-define` configuration, or
  /// returns `null` when [Auth0Config.isConfigured] is `false` so callers
  /// can fall back to another [AuthService].
  static Auth0AuthService? fromEnvironment() {
    if (!Auth0Config.isConfigured) {
      return null;
    }
    return Auth0AuthService._(Auth0(Auth0Config.domain, Auth0Config.clientId));
  }

  @override
  Future<AuthSession?> restoreSession() async {
    final hasValid = await _auth0.credentialsManager.hasValidCredentials();
    if (!hasValid) {
      return null;
    }
    final credentials = await _auth0.credentialsManager.credentials();
    return _toSession(credentials);
  }

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    try {
      final credentials = await _auth0.api.login(
        usernameOrEmail: email.trim(),
        password: password,
        connectionOrRealm: Auth0Config.connection,
        audience: Auth0Config.audience.isEmpty ? null : Auth0Config.audience,
      );
      await _auth0.credentialsManager.storeCredentials(credentials);
      return _toSession(credentials);
    } on ApiException catch (e) {
      throw _mapApiException(e);
    } catch (_) {
      throw const AuthFailure(
        AuthFailureType.unknown,
        'No fue posible iniciar sesión. Intenta nuevamente.',
      );
    }
  }

  @override
  Future<AuthSession> loginWithGoogle({bool preferSignup = false}) async {
    try {
      final credentials = await _auth0.webAuthentication().login(
        audience: Auth0Config.audience.isEmpty ? null : Auth0Config.audience,
        parameters: <String, String>{
          'connection': 'google-oauth2',
          'prompt': 'login',
          if (preferSignup) 'screen_hint': 'signup',
        },
      );
      await _auth0.credentialsManager.storeCredentials(credentials);
      return _toSession(credentials);
    } on ApiException catch (e) {
      throw _mapApiException(e);
    } catch (e) {
      final message = e.toString().toLowerCase();
      if (message.contains('cancel')) {
        throw const AuthFailure(
          AuthFailureType.cancelled,
          'Inicio de sesión con Google cancelado.',
        );
      }
      throw const AuthFailure(
        AuthFailureType.unknown,
        'No fue posible iniciar sesión con Google. Intenta nuevamente.',
      );
    }
  }

  @override
  Future<void> register({
    required String fullName,
    required String email,
    required String phoneNumber,
    required String password,
    required RegisteredUserRole role,
  }) async {
    try {
      final roleValue = role.metadataValue;
      await _auth0.api.signup(
        email: email.trim(),
        password: password,
        connection: Auth0Config.connection,
        userMetadata: <String, String>{
          'full_name': fullName.trim(),
          'phone_number': phoneNumber.trim(),
          'profile_type': roleValue,
          'role': roleValue,
        },
      );
    } on ApiException catch (e) {
      throw _mapApiException(e);
    } catch (_) {
      throw const AuthFailure(
        AuthFailureType.unknown,
        'No fue posible crear la cuenta. Intenta nuevamente.',
      );
    }
  }

  @override
  Future<void> requestPasswordReset({required String email}) async {
    try {
      await _auth0.api.resetPassword(
        email: email.trim(),
        connection: Auth0Config.connection,
      );
    } on ApiException catch (e) {
      throw _mapApiException(e);
    } catch (_) {
      throw const AuthFailure(
        AuthFailureType.unknown,
        'No fue posible enviar la recuperación. Intenta nuevamente.',
      );
    }
  }

  @override
  Future<void> logout() async {
    await _auth0.credentialsManager.clearCredentials();
  }

  AuthSession _toSession(Credentials credentials) {
    final payload = _decodeJwtPayload(credentials.idToken);
    final role = _extractRole(payload);
    final profile = credentials.user;
    final name = profile.name?.trim();
    final email = profile.email?.trim();
    return AuthSession(
      userId: profile.sub,
      name: name == null || name.isEmpty ? 'Usuario MACHUCO' : name,
      email: email == null || email.isEmpty ? 'sin-correo' : email,
      role: role,
      accessToken: credentials.accessToken,
      idToken: credentials.idToken,
    );
  }

  RegisteredUserRole _extractRole(Map<String, dynamic> payload) {
    final claimNamespace = Auth0Config.roleClaimNamespace.trim().replaceAll(
      RegExp(r'/+$'),
      '',
    );
    final claimName = Auth0Config.roleClaimName.trim();
    final claimKey = '$claimNamespace/$claimName';

    final roleCandidates = <String?>[
      payload[claimKey]?.toString(),
      payload['role']?.toString(),
      payload['profile_type']?.toString(),
      (payload['https://machuco.app/claims/role'])?.toString(),
      (payload['https://machuco.app/role'])?.toString(),
      (payload['user_metadata'] is Map<String, dynamic>)
          ? (payload['user_metadata'] as Map<String, dynamic>)['profile_type']
                ?.toString()
          : null,
      (payload['app_metadata'] is Map<String, dynamic>)
          ? (payload['app_metadata'] as Map<String, dynamic>)['role']
                ?.toString()
          : null,
    ];

    for (final candidate in roleCandidates) {
      if (candidate != null && candidate.trim().isNotEmpty) {
        return roleFromMetadataValue(candidate);
      }
    }
    return RegisteredUserRole.client;
  }

  Map<String, dynamic> _decodeJwtPayload(String token) {
    final segments = token.split('.');
    if (segments.length < 2) {
      return const <String, dynamic>{};
    }
    try {
      final normalized = base64Url.normalize(segments[1]);
      final payload = utf8.decode(base64Url.decode(normalized));
      final decoded = jsonDecode(payload);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {
      return const <String, dynamic>{};
    }
    return const <String, dynamic>{};
  }

  AuthFailure _mapApiException(ApiException exception) {
    final code = exception.code.toLowerCase();
    final message = exception.message.toLowerCase();
    if (exception.isInvalidConfiguration) {
      return const AuthFailure(
        AuthFailureType.invalidConfiguration,
        'Configuración de Auth0 inválida. Revisa domain, clientId y conexión.',
      );
    }
    if (exception.isInvalidCredentials) {
      return const AuthFailure(
        AuthFailureType.invalidCredentials,
        'Correo o contraseña incorrectos.',
      );
    }
    if (code.contains('invalid_password') ||
        code.contains('password_strength') ||
        message.contains('at least 15 characters')) {
      return const AuthFailure(
        AuthFailureType.weakPassword,
        'La contraseña debe tener al menos 15 caracteres.',
      );
    }
    if (exception.statusCode == 409 ||
        code.contains('exists') ||
        message.contains('already exists')) {
      return const AuthFailure(
        AuthFailureType.emailAlreadyExists,
        'Este correo ya está registrado.',
      );
    }
    if (exception.statusCode >= 500) {
      return const AuthFailure(
        AuthFailureType.network,
        'Servicio no disponible. Intenta nuevamente.',
      );
    }
    return AuthFailure(
      AuthFailureType.unknown,
      exception.message.isEmpty
          ? 'Ocurrió un error inesperado.'
          : exception.message,
    );
  }
}
