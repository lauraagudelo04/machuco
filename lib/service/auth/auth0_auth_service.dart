import 'package:auth0_flutter/auth0_flutter.dart';
import 'package:machuco/service/auth/auth0_config.dart';

enum AuthFailureType {
  invalidCredentials,
  emailAlreadyExists,
  weakPassword,
  invalidConfiguration,
  network,
  cancelled,
  unknown,
}

final class AuthFailure implements Exception {
  const AuthFailure(this.type, this.message);

  final AuthFailureType type;
  final String message;
}

final class AuthSession {
  const AuthSession({
    required this.userId,
    required this.name,
    required this.email,
    required this.accessToken,
    required this.idToken,
  });

  final String userId;
  final String name;
  final String email;
  final String accessToken;
  final String idToken;
}

final class Auth0AuthService {
  Auth0AuthService._(this._auth0);

  final Auth0 _auth0;

  static Auth0AuthService? fromEnvironment() {
    if (!Auth0Config.isConfigured) {
      return null;
    }
    return Auth0AuthService._(Auth0(Auth0Config.domain, Auth0Config.clientId));
  }

  Future<AuthSession?> restoreSession() async {
    final hasValid = await _auth0.credentialsManager.hasValidCredentials();
    if (!hasValid) {
      return null;
    }
    final credentials = await _auth0.credentialsManager.credentials();
    return _toSession(credentials);
  }

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

  Future<void> register({
    required String fullName,
    required String email,
    required String phoneNumber,
    required String password,
    required String profileType,
  }) async {
    try {
      await _auth0.api.signup(
        email: email.trim(),
        password: password,
        connection: Auth0Config.connection,
        userMetadata: <String, String>{
          'full_name': fullName.trim(),
          'phone_number': phoneNumber.trim(),
          'profile_type': profileType,
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

  Future<void> logout() async {
    await _auth0.credentialsManager.clearCredentials();
  }

  AuthSession _toSession(Credentials credentials) {
    final profile = credentials.user;
    final name = profile.name?.trim();
    final email = profile.email?.trim();
    return AuthSession(
      userId: profile.sub,
      name: name == null || name.isEmpty ? 'Usuario MACHUCO' : name,
      email: email == null || email.isEmpty ? 'sin-correo' : email,
      accessToken: credentials.accessToken,
      idToken: credentials.idToken,
    );
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
