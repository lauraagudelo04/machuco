import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:machuco/controllers/auth/validators/auth_input_normalizer.dart';
import 'package:machuco/database/repository/auth/administrators_repository.dart';
import 'package:machuco/database/repository/auth/user_profile_repository.dart';
import 'package:machuco/models/auth/account_status.dart';
import 'package:machuco/models/auth/person_type.dart';
import 'package:machuco/models/auth/registered_user.dart';
import 'package:machuco/models/auth/registration_data.dart';
import 'package:machuco/models/auth/user_profile.dart';
import 'package:machuco/service/auth/account_profile_removal.dart';
import 'package:machuco/service/auth/auth_service.dart';
import 'package:machuco/service/auth/phone_verification_service.dart';

/// [AuthService] implementation backed by Firebase Authentication
/// (email/password).
///
/// The session token is persisted by the Firebase SDK itself; the app never
/// stores it. The [RegisteredUserRole] and [AccountStatus] come from the
/// Firestore profile `users/{uid}`, protected by `firestore.rules` (the
/// authoritative authorization; this class only reflects it in the session).
/// A user without a profile document gets no session: it fails with
/// [AuthFailureType.profileIncomplete] and keeps the Firebase session so the
/// "Completar perfil" flow (`FirebaseSocialAuthService`) can resume it.
final class FirebaseAuthService implements AuthService {
  FirebaseAuthService({
    FirebaseAuth? firebaseAuth,
    UserProfileRepository? profileRepository,
    AdministratorsRepository? administratorsRepository,
  }) : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
       _profileRepository =
           profileRepository ?? FirestoreUserProfileRepository(),
       _administrators =
           administratorsRepository ?? FirestoreAdministratorsRepository();

  final FirebaseAuth _firebaseAuth;
  final UserProfileRepository _profileRepository;
  final AdministratorsRepository _administrators;

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

  /// Registro histórico con nombre completo. Se conserva por compatibilidad;
  /// el flujo vigente es [registerAccount].
  @override
  Future<void> register({
    required String fullName,
    required String email,
    required String phoneNumber,
    required String password,
    required RegisteredUserRole role,
  }) {
    final normalizedEmail = AuthInputNormalizer.email(email);
    return _createAccount(
      role: role,
      email: normalizedEmail,
      password: password,
      displayName: fullName.trim(),
      profile: (uid) => UserProfile(
        uid: uid,
        fullName: fullName.trim(),
        email: normalizedEmail,
        phoneNumber: phoneNumber,
        role: role,
        accountStatus: initialAccountStatusFor(role),
      ),
    );
  }

  /// Registro por rol: guarda en `users/{uid}` nombres, apellidos, indicativo,
  /// y los campos propios del rol (fecha de nacimiento para el cliente;
  /// tipo de persona, NIT, razón social y plan para el propietario). Esos
  /// datos sensibles solo viven en Firestore.
  ///
  /// El celular debe venir verificado por SMS ([RegistrationData.phoneProof]):
  /// sin esa prueba, o con la de otro número, falla con
  /// [AuthFailureType.phoneNotVerified] antes de crear nada.
  ///
  /// Simulado en el cliente: el formato ya fue validado por el controller; la
  /// autoridad real son las reglas de `firestore.rules`.
  @override
  Future<void> registerAccount(RegistrationData data) async {
    final phoneProof = requireVerifiedPhoneProof(
      data.phoneProof,
      phoneNumber: data.phoneNumber,
    );
    final normalizedEmail = AuthInputNormalizer.email(data.email);
    final firstNames = AuthInputNormalizer.text(data.firstNames);
    final lastNames = AuthInputNormalizer.text(data.lastNames);
    final isOwner = data.role == RegisteredUserRole.owner;
    final personType = data.personType;
    if (isOwner &&
        (personType == null ||
            AuthInputNormalizer.nit(data.nit) == null ||
            data.planId == null)) {
      throw const AuthFailure(
        AuthFailureType.invalidInput,
        'Faltan datos obligatorios de la cuenta de propietario.',
      );
    }
    final companyName = AuthInputNormalizer.text(data.companyName);
    return _createAccount(
      role: data.role,
      email: normalizedEmail,
      password: data.password,
      displayName: '$firstNames $lastNames'.trim(),
      phoneProof: phoneProof,
      profile: (uid) => UserProfile(
        uid: uid,
        fullName: '$firstNames $lastNames'.trim(),
        email: normalizedEmail,
        phoneNumber: data.phoneNumber,
        role: data.role,
        accountStatus: initialAccountStatusFor(data.role),
        firstNames: firstNames,
        lastNames: lastNames,
        phoneCountryCodeId: data.phoneCountryCodeId,
        birthDate: isOwner ? null : data.birthDate,
        personType: isOwner ? personType : null,
        nit: isOwner ? AuthInputNormalizer.nit(data.nit) : null,
        companyName: isOwner && personType == PersonType.juridica
            ? (companyName.isEmpty ? null : companyName)
            : null,
        planId: isOwner ? data.planId : null,
      ),
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
  ///
  /// Con [phoneProof], el celular verificado se vincula al usuario antes de
  /// guardar el perfil (Firebase comprueba el código SMS en ese momento); si
  /// falla, también se revierte la cuenta.
  Future<void> _createAccount({
    required RegisteredUserRole role,
    required String email,
    required String password,
    required String displayName,
    required UserProfile Function(String uid) profile,
    FirebasePhoneVerificationProof? phoneProof,
  }) async {
    if (!isPublicRegistrationRole(role)) {
      throw const AuthFailure(
        AuthFailureType.unknown,
        'El tipo de cuenta seleccionado no está disponible para registro.',
      );
    }
    try {
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = credential.user;
      if (user == null) {
        throw const AuthFailure(
          AuthFailureType.unknown,
          'No fue posible crear la cuenta. Intenta nuevamente.',
        );
      }
      if (phoneProof != null) {
        try {
          await linkVerifiedPhone(user, phoneProof);
        } on AuthFailure {
          await _rollbackAccount(user);
          rethrow;
        }
      }
      try {
        await user.updateDisplayName(displayName);
        await _profileRepository.createProfile(profile(user.uid));
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

  /// Reautentica con la contraseña, borra `users/{uid}` y luego el usuario de
  /// Firebase Auth. Si el perfil ya no existe (intento anterior que falló al
  /// borrar el usuario) la operación continúa: es idempotente.
  ///
  /// Un administrador no borra su perfil: lo anonimiza (falla con
  /// [AuthFailureType.lastAdministrator], sin cambios, si es el último activo)
  /// y después se borra su usuario de Auth.
  ///
  /// No comprueba reservas activas: sin backend confiable no es garantizable
  /// desde el cliente (ver contexto de la rama).
  @override
  Future<void> deleteAccount({required String password}) async {
    final user = _firebaseAuth.currentUser;
    final email = user?.email;
    if (user == null || email == null || email.isEmpty) {
      throw const AuthFailure(
        AuthFailureType.unknown,
        'No hay una sesión activa. Inicia sesión e intenta nuevamente.',
      );
    }
    try {
      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(email: email, password: password),
      );
      await removeOrAnonymizeProfile(
        profiles: _profileRepository,
        administrators: _administrators,
        uid: user.uid,
      );
      await user.delete();
      await _firebaseAuth.signOut();
    } on FirebaseAuthException catch (e) {
      throw _mapDeleteException(e);
    }
  }

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
  /// cuenta no permite el acceso, cierra sesión y lanza [AuthFailure]. Un
  /// propietario pendiente de aprobación SÍ obtiene sesión (con
  /// [AccountStatus.pendingApproval]) para ver la pantalla de revisión; las
  /// reglas de Firestore le impiden operar mientras no esté activo.
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

    if (profile == null) {
      // Riesgo R1 del plan: sin perfil no hay rol ni términos aceptados, así
      // que nunca se concede acceso de cliente por omisión. La sesión de
      // Firebase se conserva para reanudar "Completar perfil".
      throw const AuthFailure(
        AuthFailureType.profileIncomplete,
        'Completa tu perfil para continuar.',
      );
    }
    final role = profile.role;
    final String profileName = profile.fullName.trim();
    final blocked = _blockedFailure(profile);
    if (blocked != null) {
      await _firebaseAuth.signOut();
      throw blocked;
    }
    final status = profile.accountStatus ?? AccountStatus.active;

    final tokenResult = await user.getIdTokenResult();
    final idToken = tokenResult.token ?? '';
    final name = profileName.isNotEmpty
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
      accountStatus: status,
      profile: profile,
    );
  }

  /// `null` si el estado permite abrir sesión (activo, o propietario
  /// pendiente). Un estado faltante o desconocido se bloquea (nunca se
  /// concede acceso por omisión).
  AuthFailure? _blockedFailure(UserProfile profile) =>
      accountAccessFailure(profile);

  /// Regla compartida con `FirebaseSocialAuthService`: `null` si el estado
  /// permite abrir sesión. Un admin sin `accountStatus` se informa como
  /// configuración inválida (las reglas tampoco lo dejan operar).
  static AuthFailure? accountAccessFailure(UserProfile profile) {
    return switch (profile.accountStatus) {
      AccountStatus.active => null,
      AccountStatus.pendingApproval =>
        profile.role == RegisteredUserRole.owner
            ? null
            : const AuthFailure(
                AuthFailureType.unknown,
                'No pudimos verificar el estado de tu cuenta. Comunícate con '
                'el administrador.',
              ),
      AccountStatus.disabled => const AuthFailure(
        AuthFailureType.accountDisabled,
        'Tu cuenta está deshabilitada. Comunícate con el administrador.',
      ),
      AccountStatus.rejected => AuthFailure(
        AuthFailureType.accountRejected,
        'Tu solicitud de cuenta fue rechazada.',
        rejectionReason: profile.rejectionReason,
      ),
      // Neutro: no revela que fue un administrador ni quién lo eliminó.
      AccountStatus.anonymized => const AuthFailure(
        AuthFailureType.accountDeleted,
        'Esta cuenta ya no existe.',
      ),
      null when profile.role == RegisteredUserRole.admin => const AuthFailure(
        AuthFailureType.invalidConfiguration,
        'Tu cuenta de administrador no está activa; contacta a otro '
        'administrador.',
      ),
      null => const AuthFailure(
        AuthFailureType.unknown,
        'No pudimos verificar el estado de tu cuenta. Comunícate con el '
        'administrador.',
      ),
    };
  }

  AuthFailure _mapDeleteException(FirebaseAuthException exception) {
    return switch (exception.code) {
      'wrong-password' || 'invalid-credential' => const AuthFailure(
        AuthFailureType.invalidCredentials,
        'La contraseña es incorrecta.',
      ),
      'requires-recent-login' => const AuthFailure(
        AuthFailureType.requiresRecentLogin,
        'Por seguridad, inicia sesión de nuevo antes de eliminar tu cuenta.',
      ),
      _ => _mapException(exception),
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
        AuthFailureType.accountDisabled,
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
        AuthFailureType.tooManyRequests,
        'Demasiados intentos. Espera un momento e intenta nuevamente.',
      ),
      'requires-recent-login' => const AuthFailure(
        AuthFailureType.requiresRecentLogin,
        'Por seguridad, inicia sesión de nuevo para continuar.',
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
