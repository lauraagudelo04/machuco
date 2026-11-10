import 'package:machuco/models/auth/auth_provider_kind.dart';
import 'package:machuco/service/auth/auth_service.dart';

/// Resultado único del ingreso con Google o GitHub, de la reanudación de la
/// sesión y de "Completar perfil" (contrato de
/// `docs/auth/plan-auth-social.md`, sección 4).
///
/// La vista solo navega según el tipo; nunca autoriza con él (la autoridad
/// son las reglas de Firestore).
sealed class SocialAuthResult {
  const SocialAuthResult();
}

/// Perfil completo y cuenta activa: navegar a la ruta del rol.
final class SocialAuthActive extends SocialAuthResult {
  const SocialAuthActive(this.session);

  final AuthSession session;
}

/// Usuario autenticado en Firebase sin `users/{uid}`: navegar a
/// "Completar perfil". La sesión de Firebase sigue abierta.
final class SocialAuthIncompleteProfile extends SocialAuthResult {
  const SocialAuthIncompleteProfile({
    required this.uid,
    required this.email,
    required this.emailVerified,
    required this.provider,
    this.displayName,
    this.phoneNumber,
  });

  final String uid;

  /// Correo del proveedor, en solo lectura en el formulario.
  final String email;

  /// Siempre `true` para Google y GitHub (si no, el ingreso se bloquea).
  final bool emailVerified;
  final AuthProviderKind provider;

  /// Para precargar nombres y apellidos.
  final String? displayName;

  /// Celular en formato E.164 (p. ej. `+573001234567`) si el proveedor lo
  /// entregó. Google y GitHub casi nunca lo hacen; solo sirve para precargar.
  final String? phoneNumber;
}

/// Propietario `pending_approval`: sesión válida, ruta "Cuenta en revisión".
final class SocialAuthPending extends SocialAuthResult {
  const SocialAuthPending(this.session);

  final AuthSession session;
}

/// Propietario rechazado: sin sesión; mostrar el motivo.
final class SocialAuthRejected extends SocialAuthResult {
  const SocialAuthRejected({this.reason});

  final String? reason;
}

/// Cuenta deshabilitada (en Firestore o en Firebase Auth): sin sesión.
final class SocialAuthDisabled extends SocialAuthResult {
  const SocialAuthDisabled();
}

/// El usuario cerró el flujo del proveedor: permanecer en el login sin error.
final class SocialAuthCancelled extends SocialAuthResult {
  const SocialAuthCancelled();
}

/// Cualquier otro caso. [failure] trae el tipo y un mensaje en español.
///
/// Tipos propios del ingreso social: `network`, `providerMisconfigured`,
/// `accountExistsWithDifferentCredential` (con [conflictEmail]),
/// `emailUnavailable`, `emailNotVerified`, `invalidConfiguration` (p. ej.
/// admin sin `accountStatus`), `invalidInput` (al completar el perfil),
/// `tooManyRequests` y `unknown`.
final class SocialAuthError extends SocialAuthResult {
  const SocialAuthError(this.failure, {this.conflictEmail});

  final AuthFailure failure;

  /// Correo de la cuenta existente cuando el conflicto lo informa.
  final String? conflictEmail;
}
