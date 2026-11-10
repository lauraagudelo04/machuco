import 'package:machuco/models/auth/account_status.dart';
import 'package:machuco/models/auth/registered_user.dart';
import 'package:machuco/models/auth/registration_data.dart';
import 'package:machuco/models/auth/user_profile.dart';

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

  /// Propietario pendiente de aprobación (la sesión sí se crea; este tipo
  /// queda para operaciones que exigen una cuenta activa).
  accountPending,

  /// Solicitud rechazada por un administrador; ver [AuthFailure.rejectionReason].
  accountRejected,

  /// Cuenta deshabilitada (por un administrador o por Firebase Auth).
  accountDisabled,

  /// Firebase limitó los intentos (`too-many-requests`).
  tooManyRequests,

  /// La operación sensible exige volver a iniciar sesión.
  requiresRecentLogin,

  /// Dato de entrada rechazado por la validación de la aplicación.
  invalidInput,

  /// Usuario autenticado en Firebase sin `users/{uid}`: debe completar su
  /// perfil antes de entrar (nunca se le da acceso de cliente por omisión).
  profileIncomplete,

  /// El correo ya tiene una cuenta con otro método de acceso
  /// (`account-exists-with-different-credential`).
  accountExistsWithDifferentCredential,

  /// El proveedor no entregó un correo (p. ej. GitHub con correo privado).
  emailUnavailable,

  /// No se pudo comprobar que el correo del proveedor esté verificado.
  emailNotVerified,

  /// Proveedor deshabilitado o app mal configurada (SHA, OAuth App,
  /// `google-services.json`).
  providerMisconfigured,

  /// La cuenta fue anonimizada (administrador eliminado): ya no existe para
  /// el usuario. El mensaje es neutro a propósito.
  accountDeleted,

  /// Quien elimina su cuenta es el único administrador activo; primero debe
  /// existir otro (la regla real está en `firestore.rules`).
  lastAdministrator,
}

/// An error thrown by any [AuthService] implementation.
///
/// [message] is already a user-safe, Spanish-language message suitable for
/// display; it must not leak raw provider error details.
final class AuthFailure implements Exception {
  const AuthFailure(this.type, this.message, {this.rejectionReason});

  final AuthFailureType type;
  final String message;

  /// Motivo escrito por el administrador; solo con
  /// [AuthFailureType.accountRejected].
  final String? rejectionReason;
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
    this.accountStatus = AccountStatus.active,
    this.profile,
  });

  final String userId;
  final String name;
  final String email;
  final RegisteredUserRole role;
  final String accessToken;
  final String idToken;

  /// Estado de la cuenta. Un propietario `pendingApproval` tiene sesión pero
  /// debe ser dirigido a la pantalla de revisión. Solo para mostrar/enrutar:
  /// la autorización real vive en `firestore.rules`.
  final AccountStatus accountStatus;

  /// Perfil de Firestore con el que se construyó la sesión (puede ser `null`
  /// en servicios que no lo tengan).
  final UserProfile? profile;
}

/// Contract for authenticating a user and managing their session.
///
/// `FirebaseAuthService` is the only production implementation. The contract
/// is kept as the seam to inject fakes in tests; do not add alternative
/// providers.
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

  /// Registro por rol. Cliente queda `active`; propietario
  /// `pending_approval`. No deja sesión abierta.
  Future<void> registerAccount(RegistrationData data);

  Future<void> requestPasswordReset({required String email});

  Future<void> logout();

  /// Elimina la cuenta del usuario autenticado tras reautenticarlo con
  /// [password]: borra `users/{uid}` y luego el usuario de Firebase Auth.
  Future<void> deleteAccount({required String password});
}
