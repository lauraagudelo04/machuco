import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:machuco/database/repository/auth/user_profile_repository.dart';
import 'package:machuco/models/auth/account_status.dart';
import 'package:machuco/models/auth/registered_user.dart';
import 'package:machuco/models/auth/user_profile.dart';
import 'package:machuco/service/auth/auth_service.dart';

/// [AuthService] implementation backed by Firebase Authentication
/// (email/password).
///
/// The session token is persisted by the Firebase SDK itself; the app never
/// stores it. The [RegisteredUserRole] and [AccountStatus] come from the
/// Firestore profile `users/{uid}`, protected by `firestore.rules` (the
/// authoritative authorization; this class only reflects it in the session).
/// A user without a profile document is treated as an active
/// [RegisteredUserRole.client] (least privilege).
final class FirebaseAuthService implements AuthService {
  FirebaseAuthService({
    FirebaseAuth? firebaseAuth,
    UserProfileRepository? profileRepository,
  }) : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
       _profileRepository =
           profileRepository ?? FirestoreUserProfileRepository();

  final FirebaseAuth _firebaseAuth;
  final UserProfileRepository _profileRepository;

  @override
  Future<AuthSession?> restoreSession() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      return null;
    }
    try {
      await user.reload();
      return await _toSession(_firebaseAuth.currentUser ?? user);
    } on FirebaseAuthException catch (e) {
      // Sesión expirada, cuenta eliminada o deshabilitada: se descarta.
      if (e.code == 'network-request-failed') {
        throw _mapException(e);
      }
      await _firebaseAuth.signOut();
      return null;
    } on AuthFailure catch (e) {
      // Sin conexión la sesión se conserva para reintentar; una cuenta
      // bloqueada por estado (la sesión ya se cerró) se descarta.
      if (e.type == AuthFailureType.network) {
        rethrow;
      }
      return null;
    } catch (error) {
      debugPrint('Error inesperado al restaurar la sesión: $error');
      throw const AuthFailure(
        AuthFailureType.unknown,
        'No se pudo restaurar tu sesión. Intenta nuevamente.',
      );
    }
  }

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = credential.user;
      if (user == null) {
        throw const AuthFailure(
          AuthFailureType.unknown,
          'No fue posible iniciar sesión. Intenta nuevamente.',
        );
      }
      return await _toSession(user);
    } on FirebaseAuthException catch (e) {
      throw _mapException(e);
    }
  }

  /// Los proveedores externos están definidos pero no implementados en esta
  /// etapa (ver contexto de la rama).
  @override
  Future<AuthSession> loginWithGoogle({bool preferSignup = false}) async {
    throw const AuthFailure(
      AuthFailureType.invalidConfiguration,
      'El ingreso con Google aún no está disponible.',
    );
  }

  /// Crea la cuenta en Firebase Auth, guarda el perfil `users/{uid}` y cierra
  /// la sesión que el SDK abre automáticamente, para que el usuario inicie
  /// sesión de forma explícita.
  ///
  /// Solo se aceptan los roles `client` y `owner`; el registro público nunca
  /// crea administradores. El estado inicial depende del rol (propietario:
  /// pendiente de aprobación). Esta comprobación del cliente solo da un
  /// mensaje claro: la regla real está en `firestore.rules`. Si el perfil no
  /// se puede guardar, se elimina la cuenta recién creada para no dejarla
  /// huérfana.
  @override
  Future<void> register({
    required String fullName,
    required String email,
    required String phoneNumber,
    required String password,
    required RegisteredUserRole role,
  }) async {
    if (!isPublicRegistrationRole(role)) {
      throw const AuthFailure(
        AuthFailureType.unknown,
        'El tipo de cuenta seleccionado no está disponible para registro.',
      );
    }
    final normalizedEmail = email.trim().toLowerCase();
    try {
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );
      final user = credential.user;
      if (user == null) {
        throw const AuthFailure(
          AuthFailureType.unknown,
          'No fue posible crear la cuenta. Intenta nuevamente.',
        );
      }
      try {
        await user.updateDisplayName(fullName.trim());
        await _profileRepository.createProfile(
          UserProfile(
            uid: user.uid,
            fullName: fullName.trim(),
            email: normalizedEmail,
            phoneNumber: phoneNumber,
            role: role,
            accountStatus: initialAccountStatusFor(role),
          ),
        );
      } catch (error) {
        debugPrint('No fue posible guardar el perfil, se revierte: $error');
        await _rollbackAccount(user);
        if (error is UserProfileRepositoryException &&
            error.type == UserProfileFailureType.network) {
          throw const AuthFailure(
            AuthFailureType.network,
            'No hay conexión. Revisa tu internet e intenta nuevamente.',
          );
        }
        throw const AuthFailure(
          AuthFailureType.unknown,
          'No pudimos completar tu registro. Intenta nuevamente.',
        );
      }
      await _firebaseAuth.signOut();
    } on FirebaseAuthException catch (e) {
      throw _mapException(e);
    }
  }

  /// No revela si el correo existe: un `user-not-found` se trata como éxito.
  @override
  Future<void> requestPasswordReset({required String email}) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        return;
      }
      if (e.code == 'invalid-email') {
        throw const AuthFailure(
          AuthFailureType.invalidCredentials,
          'El correo no es válido.',
        );
      }
      throw _mapException(e);
    }
  }

  @override
  Future<void> logout() => _firebaseAuth.signOut();

  /// Elimina la cuenta recién creada; si no se puede, al menos cierra sesión.
  Future<void> _rollbackAccount(User user) async {
    try {
      await user.delete();
    } catch (error) {
      debugPrint('No fue posible eliminar la cuenta huérfana: $error');
      await _firebaseAuth.signOut();
    }
  }

  /// Construye la sesión a partir del perfil de Firestore. Si el estado de la
  /// cuenta no permite el acceso, cierra sesión y lanza [AuthFailure].
  Future<AuthSession> _toSession(User user) async {
    final UserProfile? profile;
    try {
      profile = await _profileRepository.getProfile(user.uid);
    } on UserProfileRepositoryException catch (e) {
      // Un error de red no cierra la sesión: el usuario podrá reintentar sin
      // volver a ingresar sus credenciales.
      if (e.type == UserProfileFailureType.network) {
        throw AuthFailure(AuthFailureType.network, e.message);
      }
      await _firebaseAuth.signOut();
      throw AuthFailure(AuthFailureType.unknown, e.message);
    }

    // TODO(auth): falta la pantalla "Cuenta en revisión" para propietarios
    // pendientes; por ahora se informa con un mensaje en el login.
    var role = RegisteredUserRole.client;
    String? profileName;
    if (profile == null) {
      debugPrint('Usuario sin perfil en Firestore; se usa rol cliente.');
    } else {
      role = profile.role;
      profileName = profile.fullName.trim();
      final blocked = _blockedFailure(profile.accountStatus);
      if (blocked != null) {
        await _firebaseAuth.signOut();
        throw blocked;
      }
    }

    final tokenResult = await user.getIdTokenResult();
    final idToken = tokenResult.token ?? '';
    final name = (profileName != null && profileName.isNotEmpty)
        ? profileName
        : user.displayName?.trim();
    final email = user.email?.trim();
    return AuthSession(
      userId: user.uid,
      name: name == null || name.isEmpty ? 'Usuario MACHUCO' : name,
      email: email == null || email.isEmpty ? 'sin-correo' : email,
      role: role,
      accessToken: idToken,
      idToken: idToken,
    );
  }

  /// `null` si el estado permite iniciar sesión. Un estado faltante o
  /// desconocido se bloquea (nunca se concede acceso por omisión).
  AuthFailure? _blockedFailure(AccountStatus? status) {
    return switch (status) {
      AccountStatus.active => null,
      AccountStatus.disabled => const AuthFailure(
        AuthFailureType.unknown,
        'Tu cuenta está deshabilitada. Comunícate con el administrador.',
      ),
      AccountStatus.rejected => const AuthFailure(
        AuthFailureType.unknown,
        'Tu solicitud de cuenta fue rechazada. Comunícate con el '
        'administrador.',
      ),
      AccountStatus.pendingApproval => const AuthFailure(
        AuthFailureType.unknown,
        'Tu cuenta de propietario está en revisión. Te avisaremos cuando '
        'sea aprobada.',
      ),
      null => const AuthFailure(
        AuthFailureType.unknown,
        'No pudimos verificar el estado de tu cuenta. Comunícate con el '
        'administrador.',
      ),
    };
  }

  AuthFailure _mapException(FirebaseAuthException exception) {
    return switch (exception.code) {
      'invalid-credential' ||
      'invalid-email' ||
      'wrong-password' ||
      'user-not-found' => const AuthFailure(
        AuthFailureType.invalidCredentials,
        'Correo o contraseña incorrectos.',
      ),
      'user-disabled' => const AuthFailure(
        AuthFailureType.unknown,
        'Tu cuenta está deshabilitada. Comunícate con el administrador.',
      ),
      'email-already-in-use' => const AuthFailure(
        AuthFailureType.emailAlreadyExists,
        'Este correo ya está registrado.',
      ),
      'weak-password' => const AuthFailure(
        AuthFailureType.weakPassword,
        'La contraseña es demasiado débil.',
      ),
      'network-request-failed' => const AuthFailure(
        AuthFailureType.network,
        'No hay conexión. Revisa tu internet e intenta nuevamente.',
      ),
      'too-many-requests' => const AuthFailure(
        AuthFailureType.network,
        'Demasiados intentos. Espera un momento e intenta nuevamente.',
      ),
      'operation-not-allowed' => const AuthFailure(
        AuthFailureType.invalidConfiguration,
        'El ingreso con correo y contraseña no está habilitado en Firebase.',
      ),
      _ => const AuthFailure(
        AuthFailureType.unknown,
        'Ocurrió un error inesperado. Intenta nuevamente.',
      ),
    };
  }
}
