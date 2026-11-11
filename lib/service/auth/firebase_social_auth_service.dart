import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:machuco/controllers/auth/validators/auth_input_normalizer.dart';
import 'package:machuco/controllers/auth/validators/auth_validators.dart';
import 'package:machuco/database/repository/auth/administrators_repository.dart';
import 'package:machuco/database/repository/auth/auth_user_profile_repository.dart';
import 'package:machuco/database/repository/auth/user_profile_repository.dart';
import 'package:machuco/models/auth/account_status.dart';
import 'package:machuco/models/auth/auth_provider_kind.dart';
import 'package:machuco/models/auth/person_type.dart';
import 'package:machuco/models/auth/registered_user.dart';
import 'package:machuco/models/auth/social_auth_result.dart';
import 'package:machuco/models/auth/social_profile_data.dart';
import 'package:machuco/models/auth/user_profile.dart';
import 'package:machuco/service/analytics/analytics_service.dart';
import 'package:machuco/service/auth/account_profile_removal.dart';
import 'package:machuco/service/auth/auth_service.dart';
import 'package:machuco/service/auth/firebase_auth_service.dart';
import 'package:machuco/service/auth/github_email_verifier.dart';
import 'package:machuco/service/auth/phone_verification_service.dart';

/// Ingreso, registro y gestión de proveedores con Google y GitHub
/// (`docs/auth/plan-auth-social.md`, etapas 1, 3 y 4).
///
/// Todo resultado de ingreso es un [SocialAuthResult]; las operaciones de
/// cuenta (vincular, desvincular, eliminar) lanzan [AuthFailure].
abstract interface class SocialAuthService {
  /// Google con `signInWithProvider` (decisión D4; en web, `signInWithPopup`).
  /// Exige correo verificado
  /// (D7).
  Future<SocialAuthResult> signInWithGoogle();

  /// GitHub con `signInWithProvider` y alcance `user:email`. Bloquea si
  /// GitHub no confirma un correo verificado (D5).
  Future<SocialAuthResult> signInWithGitHub();

  /// Resultado para la sesión de Firebase ya abierta (arranque de la app);
  /// `null` si no hay sesión o no se puede reanudar.
  Future<SocialAuthResult?> resumeSession();

  /// Crea `users/{uid}` con [data] si aún no existe (idempotente). El celular
  /// debe venir verificado por SMS ([SocialProfileData.phoneProof]) y se vincula
  /// al usuario antes de guardar el perfil; sin esa prueba falla con
  /// [AuthFailureType.phoneNotVerified].
  Future<SocialAuthResult> completeProfile(SocialProfileData data);

  /// Abandono de "Completar perfil" (D10): borra el usuario de Firebase si solo
  /// entra con proveedores sociales y se confirma que no tiene perfil, y cierra
  /// la sesión. Si no se puede borrar (sin red, sin inicio de sesión reciente),
  /// solo cierra la sesión y al volver a entrar se retoma el formulario.
  Future<void> abandonProfileCompletion();

  /// Proveedor que quedó pendiente de vincular tras un conflicto de correo.
  AuthProviderKind? get pendingLinkProvider;

  /// Correo de la cuenta existente en ese conflicto (si Firebase lo dio).
  String? get pendingLinkEmail;

  /// Tras iniciar sesión con el método original, vincula el proveedor
  /// pendiente al mismo usuario.
  Future<void> linkPendingProvider();

  Future<void> linkProvider(AuthProviderKind kind);

  /// No permite quitar el último método de acceso.
  Future<void> unlinkProvider(AuthProviderKind kind);

  List<AuthProviderKind> get linkedProviders;

  /// Reautentica con [password] si la cuenta tiene contraseña y se envió;
  /// si no, con su proveedor social. Luego borra `users/{uid}` (un
  /// administrador lo anonimiza), el usuario de Firebase y el perfil local.
  Future<void> deleteAccount({String? password});

  /// Cierra la sesión de Firebase (con `signInWithProvider` no hay sesión
  /// aparte de Google que cerrar) y borra el perfil local.
  Future<void> signOut();
}

final class FirebaseSocialAuthService implements SocialAuthService {
  FirebaseSocialAuthService({
    FirebaseAuth? firebaseAuth,
    UserProfileRepository? profileRepository,
    AuthUserProfileRepository? profileCache,
    GitHubEmailVerifier? gitHubEmailVerifier,
    DateTime Function()? clock,
    bool? useWebPopups,
    AdministratorsRepository? administratorsRepository,
    AnalyticsService? analytics,
  }) : _analytics = analytics,
       _usePopups = useWebPopups ?? kIsWeb,
       _auth = firebaseAuth ?? FirebaseAuth.instance,
       _profiles = profileRepository ?? FirestoreUserProfileRepository(),
       _administrators =
           administratorsRepository ?? FirestoreAdministratorsRepository(),
       _cache = profileCache ?? FloorAuthUserProfileRepository(),
       _gitHub = gitHubEmailVerifier ?? GitHubEmailVerifier(),
       _clock = clock ?? DateTime.now;

  final FirebaseAuth _auth;
  final UserProfileRepository _profiles;
  final AdministratorsRepository _administrators;
  final AuthUserProfileRepository _cache;
  final GitHubEmailVerifier _gitHub;
  final DateTime Function() _clock;
  final AnalyticsService? _analytics;

  /// En web `signInWithProvider`, `linkWithProvider` y
  /// `reauthenticateWithProvider` no existen (`UnimplementedError`); allí se
  /// usan las variantes con ventana emergente.
  final bool _usePopups;

  AuthCredential? _pendingCredential;
  AuthProviderKind? _pendingProvider;
  String? _pendingEmail;

  static const _cancelCodes = {
    'web-context-canceled',
    'web-context-cancelled',
    'web-operation-canceled',
    'canceled',
    'cancelled',
    'user-cancelled',
    'popup-closed-by-user',
    'cancelled-popup-request',
  };

  static const _misconfiguredCodes = {
    'operation-not-allowed',
    'app-not-authorized',
    'invalid-api-key',
    'unauthorized-domain',
    'invalid-cert-hash',
    'invalid-oauth-client-id',
    'invalid-oauth-provider',
    'missing-client-identifier',
  };

  @override
  AuthProviderKind? get pendingLinkProvider => _pendingProvider;

  @override
  String? get pendingLinkEmail => _pendingEmail;

  @override
  List<AuthProviderKind> get linkedProviders => _providersOf(_auth.currentUser);

  /// Proveedor de Firebase para [kind]. Google pide elegir cuenta en cada
  /// ingreso para que "Cerrar sesión" permita cambiar de cuenta, y declara sus
  /// alcances porque en Android solo se envían los explícitos: sin `profile`
  /// Google no entrega el nombre para precargar "Completar perfil".
  @visibleForTesting
  static AuthProvider providerFor(AuthProviderKind kind) => switch (kind) {
    AuthProviderKind.google =>
      GoogleAuthProvider()
        ..addScope('email')
        ..addScope('profile')
        ..setCustomParameters({'prompt': 'select_account'}),
    AuthProviderKind.github => GithubAuthProvider()..addScope('user:email'),
    AuthProviderKind.password => throw ArgumentError.value(
      kind,
      'kind',
      'La contraseña no usa signInWithProvider',
    ),
  };

  @override
  Future<SocialAuthResult> signInWithGoogle() =>
      _signInReported(AuthProviderKind.google);

  @override
  Future<SocialAuthResult> signInWithGitHub() =>
      _signInReported(AuthProviderKind.github);

  /// Reports `login` only when the provider opened a session with a complete
  /// profile; a new user is reported as `sign_up` in [completeProfile].
  Future<SocialAuthResult> _signInReported(AuthProviderKind kind) async {
    final result = await _signIn(kind);
    if (result is SocialAuthActive || result is SocialAuthPending) {
      unawaited(_analyticsService.logLogin(kind.name));
    }
    return result;
  }

  AnalyticsService get _analyticsService =>
      _analytics ?? AnalyticsServiceProvider.instance;

  Future<SocialAuthResult> _signIn(AuthProviderKind kind) async {
    final UserCredential credential;
    try {
      final provider = providerFor(kind);
      credential = _usePopups
          ? await _auth.signInWithPopup(provider)
          : await _auth.signInWithProvider(provider);
    } on FirebaseAuthException catch (e) {
      return _signInError(e, kind);
    } on UnimplementedError catch (e) {
      // Plataforma sin soporte para este flujo (p. ej. escritorio).
      debugPrint('Ingreso con ${kind.providerId} no soportado: $e');
      return SocialAuthError(
        AuthFailure(
          AuthFailureType.providerMisconfigured,
          'El ingreso con ${kind.displayName} no está disponible en esta '
          'plataforma.',
        ),
      );
    }

    final user = credential.user;
    if (user == null) {
      return const SocialAuthError(
        AuthFailure(
          AuthFailureType.unknown,
          'No fue posible iniciar sesión. Intenta nuevamente.',
        ),
      );
    }

    final email = user.email?.trim();
    if (email == null || email.isEmpty) {
      await _signOutQuietly();
      return SocialAuthError(
        AuthFailure(
          AuthFailureType.emailUnavailable,
          kind == AuthProviderKind.github
              ? 'Tu cuenta de GitHub no comparte un correo verificado. Hazlo '
                    'público o verificado en GitHub, o regístrate con correo y '
                    'contraseña.'
              : 'Tu cuenta de ${kind.displayName} no entregó un correo.',
        ),
      );
    }

    final verified = await _isEmailVerified(user, kind, credential, email);
    if (verified case final SocialAuthError error) {
      await _signOutQuietly();
      return error;
    }

    _clearPending();
    return _resolve(user, kind, emailConfirmed: true);
  }

  /// `null` si el correo está verificado; si no, el error a devolver.
  Future<SocialAuthError?> _isEmailVerified(
    User user,
    AuthProviderKind kind,
    UserCredential credential,
    String email,
  ) async {
    if (user.emailVerified) return null;
    if (kind == AuthProviderKind.github) {
      final token = credential.credential?.accessToken;
      if (token != null && token.isNotEmpty) {
        try {
          if (await _gitHub.isVerified(accessToken: token, email: email)) {
            return null;
          }
        } on GitHubEmailVerificationNetworkException {
          return const SocialAuthError(
            AuthFailure(
              AuthFailureType.network,
              'No hay conexión. Revisa tu internet e intenta nuevamente.',
            ),
          );
        }
      }
    }
    return SocialAuthError(
      AuthFailure(
        AuthFailureType.emailNotVerified,
        'No pudimos confirmar que el correo de ${kind.displayName} esté '
        'verificado. Verifícalo en ${kind.displayName} e intenta de nuevo.',
      ),
    );
  }

  SocialAuthResult _signInError(
    FirebaseAuthException e,
    AuthProviderKind kind,
  ) {
    debugPrint('Ingreso con ${kind.providerId} falló: ${e.code}');
    final message = e.message ?? '';
    if (_cancelCodes.contains(e.code) || message.contains('access_denied')) {
      return const SocialAuthCancelled();
    }
    if (e.code == 'unsupported-platform' ||
        e.code == 'unsupported-platform-operation') {
      return SocialAuthError(
        AuthFailure(
          AuthFailureType.providerMisconfigured,
          'El ingreso con ${kind.displayName} no está disponible en esta '
          'plataforma. Usa la versión web o Android, o ingresa con correo '
          'y contraseña si tu cuenta tiene ese método.',
        ),
      );
    }
    if (e.code == 'account-exists-with-different-credential') {
      _pendingCredential = e.credential;
      _pendingProvider = kind;
      _pendingEmail = e.email;
      return SocialAuthError(
        AuthFailure(
          AuthFailureType.accountExistsWithDifferentCredential,
          'Ya existe una cuenta con este correo. Inicia sesión con el método '
          'que usaste al registrarte para vincular ${kind.displayName}.',
        ),
        conflictEmail: e.email,
      );
    }
    if (_misconfiguredCodes.contains(e.code) ||
        message.contains('DEVELOPER_ERROR')) {
      return SocialAuthError(
        AuthFailure(
          AuthFailureType.providerMisconfigured,
          'El ingreso con ${kind.displayName} no está configurado en esta '
          'versión de la app.',
        ),
      );
    }
    return switch (e.code) {
      'user-disabled' => const SocialAuthDisabled(),
      'popup-blocked' => const SocialAuthError(
        AuthFailure(
          AuthFailureType.providerMisconfigured,
          'El navegador bloqueó la ventana de inicio de sesión. Permite las '
          'ventanas emergentes para este sitio e intenta de nuevo.',
        ),
      ),
      'network-request-failed' => const SocialAuthError(
        AuthFailure(
          AuthFailureType.network,
          'No hay conexión. Revisa tu internet e intenta nuevamente.',
        ),
      ),
      'too-many-requests' => const SocialAuthError(
        AuthFailure(
          AuthFailureType.tooManyRequests,
          'Demasiados intentos. Espera un momento e intenta de nuevo.',
        ),
      ),
      _ => const SocialAuthError(
        AuthFailure(
          AuthFailureType.unknown,
          'No fue posible iniciar sesión. Intenta nuevamente.',
        ),
      ),
    };
  }

  @override
  Future<SocialAuthResult?> resumeSession() async {
    final current = _auth.currentUser;
    if (current == null) return null;
    try {
      await current.reload();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'network-request-failed') {
        return const SocialAuthError(
          AuthFailure(
            AuthFailureType.network,
            'No hay conexión. Revisa tu internet e intenta nuevamente.',
          ),
        );
      }
      await _signOutQuietly();
      return e.code == 'user-disabled' ? const SocialAuthDisabled() : null;
    }
    final user = _auth.currentUser ?? current;
    final kind = _primaryProvider(user);
    // Al reanudar solo vale la verificación que Firebase conserva.
    final result = await _resolve(
      user,
      kind,
      emailConfirmed: user.emailVerified,
    );
    // Un perfil incompleto de GitHub no se puede reanudar si Firebase no
    // marca el correo como verificado: el token de GitHub ya no está y no se
    // concede acceso sin confirmarlo (D5). Debe volver a ingresar.
    if (result is SocialAuthIncompleteProfile && !result.emailVerified) {
      await _signOutQuietly();
      return null;
    }
    return result;
  }

  /// Lee `users/{uid}` y traduce su estado. Sincroniza SQLite cuando hay
  /// sesión; un fallo de SQLite no bloquea el ingreso.
  Future<SocialAuthResult> _resolve(
    User user,
    AuthProviderKind kind, {
    required bool emailConfirmed,
  }) async {
    final UserProfile? profile;
    try {
      profile = await _profiles.getProfile(user.uid);
    } on UserProfileRepositoryException catch (e) {
      if (e.type == UserProfileFailureType.network) {
        return SocialAuthError(AuthFailure(AuthFailureType.network, e.message));
      }
      await _signOutQuietly();
      return SocialAuthError(AuthFailure(AuthFailureType.unknown, e.message));
    }

    if (profile == null) {
      return SocialAuthIncompleteProfile(
        uid: user.uid,
        email: AuthInputNormalizer.email(user.email),
        emailVerified: emailConfirmed,
        provider: kind,
        displayName: _firstNonEmpty(
          user.displayName,
          user.providerData.map((info) => info.displayName),
        ),
        phoneNumber: _firstNonEmpty(
          user.phoneNumber,
          user.providerData.map((info) => info.phoneNumber),
        ),
      );
    }
    return _resultForProfile(user, profile);
  }

  Future<SocialAuthResult> _resultForProfile(
    User user,
    UserProfile profile,
  ) async {
    final blocked = FirebaseAuthService.accountAccessFailure(profile);
    if (blocked != null) {
      await _signOutQuietly();
      await _clearCacheQuietly();
      return switch (blocked.type) {
        AuthFailureType.accountRejected => SocialAuthRejected(
          reason: blocked.rejectionReason,
        ),
        AuthFailureType.accountDisabled => const SocialAuthDisabled(),
        _ => SocialAuthError(blocked),
      };
    }

    final session = await _sessionFor(user, profile);
    await _saveCacheQuietly(profile);
    return session.accountStatus == AccountStatus.pendingApproval
        ? SocialAuthPending(session)
        : SocialAuthActive(session);
  }

  Future<AuthSession> _sessionFor(User user, UserProfile profile) async {
    var idToken = '';
    try {
      idToken = (await user.getIdTokenResult()).token ?? '';
    } on FirebaseAuthException catch (e) {
      debugPrint('No fue posible leer el token: ${e.code}');
    }
    final name = profile.fullName.trim().isNotEmpty
        ? profile.fullName.trim()
        : (user.displayName?.trim() ?? '');
    return AuthSession(
      userId: user.uid,
      name: name.isEmpty ? 'Usuario MACHUCO' : name,
      email: profile.email.isNotEmpty
          ? profile.email
          : AuthInputNormalizer.email(user.email),
      role: profile.role,
      accessToken: idToken,
      idToken: idToken,
      accountStatus: profile.accountStatus ?? AccountStatus.active,
      profile: profile,
    );
  }

  @override
  Future<SocialAuthResult> completeProfile(SocialProfileData data) async {
    final user = _auth.currentUser;
    if (user == null) {
      return const SocialAuthError(
        AuthFailure(
          AuthFailureType.unknown,
          'Tu sesión terminó. Vuelve a ingresar para completar tu perfil.',
        ),
      );
    }
    final email = AuthInputNormalizer.email(user.email);
    if (email.isEmpty) {
      return const SocialAuthError(
        AuthFailure(
          AuthFailureType.emailUnavailable,
          'Tu cuenta no tiene un correo. Ingresa con otro método.',
        ),
      );
    }

    final invalid = _validate(data);
    if (invalid != null) {
      return SocialAuthError(
        AuthFailure(AuthFailureType.invalidInput, invalid),
      );
    }

    // Idempotencia: si el perfil ya existe (doble toque, reintento tras un
    // corte o completado en otro dispositivo) no se sobrescribe.
    try {
      final existing = await _profiles.getProfile(user.uid);
      if (existing != null) return _resultForProfile(user, existing);
    } on UserProfileRepositoryException catch (e) {
      return SocialAuthError(_profileFailure(e));
    }

    final phoneFailure = await _linkVerifiedPhone(user, data);
    if (phoneFailure != null) return SocialAuthError(phoneFailure);

    final profile = _profileFrom(user.uid, email, data);
    try {
      await _profiles.createProfile(profile);
    } on UserProfileRepositoryException catch (e) {
      // Una carrera puede haberlo creado entre la lectura y la escritura.
      if (e.type == UserProfileFailureType.permissionDenied) {
        try {
          final existing = await _profiles.getProfile(user.uid);
          if (existing != null) return _resultForProfile(user, existing);
        } on UserProfileRepositoryException {
          // Se informa el error original.
        }
      }
      return SocialAuthError(_profileFailure(e));
    }
    final result = await _resultForProfile(user, profile);
    final provider = _providersOf(user).where((kind) => kind.isSocial);
    if (provider.isNotEmpty &&
        (result is SocialAuthActive || result is SocialAuthPending)) {
      unawaited(_analyticsService.logSignUp(provider.first.name));
    }
    return result;
  }

  /// `null` si el celular ya quedó vinculado al usuario (ahora o en un intento
  /// anterior que se cortó antes de guardar el perfil); si no, el motivo. El
  /// usuario no se borra: puede reintentar con otro código.
  Future<AuthFailure?> _linkVerifiedPhone(
    User user,
    SocialProfileData data,
  ) async {
    if (user.phoneNumber == data.phoneNumber) return null;
    try {
      final proof = requireVerifiedPhoneProof(
        data.phoneProof,
        phoneNumber: data.phoneNumber,
      );
      await linkVerifiedPhone(user, proof);
      return null;
    } on AuthFailure catch (failure) {
      return failure;
    }
  }

  String? _validate(SocialProfileData data) {
    if (!isPublicRegistrationRole(data.role)) {
      return 'El tipo de cuenta seleccionado no está disponible.';
    }
    final common = [
      AuthValidators.firstNames(data.firstNames),
      AuthValidators.lastNames(data.lastNames),
      AuthInputNormalizer.digits(data.phoneNumber).length < 4
          ? 'Ingresa tu número de celular.'
          : null,
      data.phoneCountryCodeId <= 0 ? 'Selecciona el indicativo.' : null,
    ];
    final roleErrors = switch (data.role) {
      RegisteredUserRole.client => [
        AuthValidators.birthDate(data.birthDate, clock: _clock),
      ],
      RegisteredUserRole.owner => [
        data.personType == null
            ? 'Selecciona el tipo de persona.'
            : AuthValidators.nit(data.personType!)(data.nit),
        data.personType == PersonType.juridica
            ? AuthValidators.companyName(data.companyName)
            : null,
        data.planId == null ? 'Selecciona un plan.' : null,
      ],
      RegisteredUserRole.admin => ['El tipo de cuenta no está disponible.'],
    };
    return [...common, ...roleErrors].whereType<String>().firstOrNull;
  }

  UserProfile _profileFrom(String uid, String email, SocialProfileData data) {
    final isOwner = data.role == RegisteredUserRole.owner;
    final firstNames = AuthInputNormalizer.text(data.firstNames);
    final lastNames = AuthInputNormalizer.text(data.lastNames);
    final companyName = AuthInputNormalizer.text(data.companyName);
    return UserProfile(
      uid: uid,
      fullName: '$firstNames $lastNames'.trim(),
      email: email,
      phoneNumber: data.phoneNumber.trim(),
      role: data.role,
      accountStatus: initialAccountStatusFor(data.role),
      firstNames: firstNames,
      lastNames: lastNames,
      phoneCountryCodeId: data.phoneCountryCodeId,
      birthDate: isOwner ? null : data.birthDate,
      personType: isOwner ? data.personType : null,
      nit: isOwner ? AuthInputNormalizer.nit(data.nit) : null,
      companyName: isOwner && data.personType == PersonType.juridica
          ? (companyName.isEmpty ? null : companyName)
          : null,
      planId: isOwner ? data.planId : null,
    );
  }

  AuthFailure _profileFailure(UserProfileRepositoryException e) => AuthFailure(
    e.type == UserProfileFailureType.network
        ? AuthFailureType.network
        : AuthFailureType.unknown,
    e.message,
  );

  @override
  Future<void> abandonProfileCompletion() async {
    _clearPending();
    final user = _auth.currentUser;
    if (user != null && await _isAbandonedSocialUser(user)) {
      try {
        await user.delete();
      } on FirebaseAuthException catch (e) {
        // `requires-recent-login` o sin red: no se abre otro flujo del
        // proveedor para cancelar; el usuario queda y se retoma al volver.
        debugPrint('No fue posible borrar el usuario sin perfil: ${e.code}');
      }
    }
    await _auth.signOut();
  }

  /// `true` solo si el usuario entra únicamente con proveedores sociales y se
  /// confirmó que no tiene perfil. Ante cualquier duda (error al leer, cuenta
  /// con contraseña) no se considera abandonado: nunca se borra una cuenta real.
  Future<bool> _isAbandonedSocialUser(User user) async {
    final linked = _providersOf(user);
    if (linked.isEmpty || !linked.every((kind) => kind.isSocial)) return false;
    try {
      return await _profiles.getProfile(user.uid) == null;
    } on UserProfileRepositoryException catch (e) {
      debugPrint('No se pudo confirmar el perfil al cancelar: ${e.type}');
      return false;
    }
  }

  @override
  Future<void> linkPendingProvider() async {
    final user = _requireUser();
    final kind = _pendingProvider;
    if (kind == null) {
      throw const AuthFailure(
        AuthFailureType.invalidInput,
        'No hay un método de acceso pendiente por vincular.',
      );
    }
    final pending = _pendingCredential;
    try {
      if (pending != null) {
        await user.linkWithCredential(pending);
      } else {
        await _linkWith(user, kind);
      }
    } on FirebaseAuthException catch (e) {
      if (e.code != 'provider-already-linked') throw _linkFailure(e, kind);
    }
    _clearPending();
  }

  @override
  Future<void> linkProvider(AuthProviderKind kind) async {
    final user = _requireUser();
    if (!kind.isSocial) {
      throw const AuthFailure(
        AuthFailureType.invalidInput,
        'Para agregar una contraseña usa "¿Olvidaste tu contraseña?".',
      );
    }
    try {
      await _linkWith(user, kind);
    } on FirebaseAuthException catch (e) {
      if (e.code != 'provider-already-linked') throw _linkFailure(e, kind);
    }
  }

  @override
  Future<void> unlinkProvider(AuthProviderKind kind) async {
    final user = _requireUser();
    final linked = _providersOf(user);
    if (!linked.contains(kind)) return;
    if (linked.length <= 1) {
      throw const AuthFailure(
        AuthFailureType.invalidInput,
        'No puedes quitar tu único método de acceso.',
      );
    }
    try {
      await user.unlink(kind.providerId);
    } on FirebaseAuthException catch (e) {
      throw _linkFailure(e, kind);
    }
  }

  AuthFailure _linkFailure(FirebaseAuthException e, AuthProviderKind kind) {
    if (_cancelCodes.contains(e.code)) {
      return const AuthFailure(
        AuthFailureType.cancelled,
        'Se canceló la vinculación.',
      );
    }
    return switch (e.code) {
      'credential-already-in-use' || 'email-already-in-use' => AuthFailure(
        AuthFailureType.accountExistsWithDifferentCredential,
        'Esa cuenta de ${kind.displayName} ya está vinculada a otro usuario.',
      ),
      'requires-recent-login' => const AuthFailure(
        AuthFailureType.requiresRecentLogin,
        'Por seguridad, vuelve a iniciar sesión e intenta de nuevo.',
      ),
      'network-request-failed' => const AuthFailure(
        AuthFailureType.network,
        'No hay conexión. Revisa tu internet e intenta nuevamente.',
      ),
      _ => AuthFailure(
        AuthFailureType.unknown,
        'No fue posible actualizar ${kind.displayName}. Intenta nuevamente.',
      ),
    };
  }

  @override
  Future<void> deleteAccount({String? password}) async {
    final user = _requireUser();
    final linked = _providersOf(user);
    final hasPassword = password != null && password.isNotEmpty;
    try {
      if (hasPassword && linked.contains(AuthProviderKind.password)) {
        final email = user.email;
        if (email == null || email.isEmpty) {
          throw const AuthFailure(
            AuthFailureType.unknown,
            'Tu cuenta no tiene correo. Confirma con tu proveedor.',
          );
        }
        await user.reauthenticateWithCredential(
          EmailAuthProvider.credential(email: email, password: password),
        );
      } else if (linked.contains(AuthProviderKind.google)) {
        await _reauthenticateWith(user, AuthProviderKind.google);
      } else if (linked.contains(AuthProviderKind.github)) {
        await _reauthenticateWith(user, AuthProviderKind.github);
      } else {
        throw const AuthFailure(
          AuthFailureType.invalidInput,
          'Ingresa tu contraseña para eliminar la cuenta.',
        );
      }
    } on FirebaseAuthException catch (e) {
      throw _reauthFailure(e);
    }

    // Cliente y propietario: borra `users/{uid}`. Administrador: lo anonimiza
    // (o falla con `lastAdministrator` sin cambios).
    await removeOrAnonymizeProfile(
      profiles: _profiles,
      administrators: _administrators,
      uid: user.uid,
    );
    try {
      await user.delete();
    } on FirebaseAuthException catch (e) {
      throw _reauthFailure(e);
    }
    _clearPending();
    await _signOutQuietly();
    await _clearCacheQuietly();
  }

  AuthFailure _reauthFailure(FirebaseAuthException e) {
    if (_cancelCodes.contains(e.code)) {
      return const AuthFailure(
        AuthFailureType.cancelled,
        'Se canceló la confirmación. Tu cuenta no se eliminó.',
      );
    }
    return switch (e.code) {
      'wrong-password' || 'invalid-credential' => const AuthFailure(
        AuthFailureType.invalidCredentials,
        'La contraseña es incorrecta.',
      ),
      'user-mismatch' => const AuthFailure(
        AuthFailureType.invalidCredentials,
        'Confirma con la misma cuenta con la que iniciaste sesión.',
      ),
      'requires-recent-login' => const AuthFailure(
        AuthFailureType.requiresRecentLogin,
        'Por seguridad, inicia sesión de nuevo antes de eliminar tu cuenta.',
      ),
      'network-request-failed' => const AuthFailure(
        AuthFailureType.network,
        'No hay conexión. Revisa tu internet e intenta nuevamente.',
      ),
      'too-many-requests' => const AuthFailure(
        AuthFailureType.tooManyRequests,
        'Demasiados intentos. Espera un momento e intenta de nuevo.',
      ),
      _ => const AuthFailure(
        AuthFailureType.unknown,
        'No fue posible eliminar tu cuenta. Intenta nuevamente.',
      ),
    };
  }

  @override
  Future<void> signOut() async {
    _clearPending();
    await _auth.signOut();
    await _clearCacheQuietly();
  }

  Future<void> _linkWith(User user, AuthProviderKind kind) => _usePopups
      ? user.linkWithPopup(providerFor(kind))
      : user.linkWithProvider(providerFor(kind));

  Future<void> _reauthenticateWith(User user, AuthProviderKind kind) =>
      _usePopups
      ? user.reauthenticateWithPopup(providerFor(kind))
      : user.reauthenticateWithProvider(providerFor(kind));

  User _requireUser() {
    final user = _auth.currentUser;
    if (user == null) {
      throw const AuthFailure(
        AuthFailureType.unknown,
        'No hay una sesión activa. Inicia sesión e intenta nuevamente.',
      );
    }
    return user;
  }

  /// [primary] si tiene texto; si no, el primer valor no vacío de los datos
  /// de cada proveedor (Firebase a veces deja vacío el principal).
  static String? _firstNonEmpty(String? primary, Iterable<String?> fallback) {
    for (final value in [primary, ...fallback]) {
      final text = value?.trim();
      if (text != null && text.isNotEmpty) return text;
    }
    return null;
  }

  static List<AuthProviderKind> _providersOf(User? user) => [
    for (final info in user?.providerData ?? const <UserInfo>[])
      ?AuthProviderKind.fromProviderId(info.providerId),
  ];

  /// Proveedor con el que se presenta el usuario al reanudar: social si lo
  /// tiene (Google primero), si no contraseña.
  static AuthProviderKind _primaryProvider(User user) {
    final linked = _providersOf(user);
    if (linked.contains(AuthProviderKind.google)) {
      return AuthProviderKind.google;
    }
    if (linked.contains(AuthProviderKind.github)) {
      return AuthProviderKind.github;
    }
    return AuthProviderKind.password;
  }

  void _clearPending() {
    _pendingCredential = null;
    _pendingProvider = null;
    _pendingEmail = null;
  }

  Future<void> _signOutQuietly() async {
    try {
      await _auth.signOut();
    } catch (error) {
      debugPrint('No fue posible cerrar la sesión: $error');
    }
  }

  Future<void> _saveCacheQuietly(UserProfile profile) async {
    try {
      await _cache.saveCurrent(profile);
    } catch (error) {
      // Escenario "Falla al guardar el perfil en SQLite": no bloquea.
      debugPrint('No fue posible guardar el perfil local: $error');
    }
  }

  Future<void> _clearCacheQuietly() async {
    try {
      await _cache.clear();
    } catch (error) {
      debugPrint('No fue posible borrar el perfil local: $error');
    }
  }
}
