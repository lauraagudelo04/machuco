import 'package:flutter/material.dart';
import 'package:machuco/controllers/auth/auth_routes.dart';
import 'package:machuco/controllers/auth/login_controller.dart';
import 'package:machuco/models/auth/auth_provider_kind.dart';
import 'package:machuco/models/auth/social_auth_result.dart';
import 'package:machuco/service/auth/auth_service.dart';
import 'package:machuco/service/auth/firebase_social_auth_service.dart';
import 'package:machuco/views/account_review/account_review_page.dart';
import 'package:machuco/views/register/complete_profile_page.dart';

/// Servicio social de producción, o `null` si Firebase no está disponible
/// (p. ej. en pruebas de widgets sin `Firebase.initializeApp`).
SocialAuthService? buildSocialAuthService() {
  try {
    return FirebaseSocialAuthService();
  } catch (error) {
    debugPrint('Ingreso social no disponible: $error');
    return null;
  }
}

/// Lleva a cada usuario según su [SocialAuthResult] (decisión de navegación
/// únicamente: la lógica vive en el servicio y la autorización en las reglas).
///
/// Devuelve el aviso que la pantalla actual debe mostrar, o `null` si navegó
/// o no hay nada que mostrar (cancelación).
Future<AuthFailure?> routeSocialResult(
  BuildContext context, {
  required SocialAuthResult result,
  required LoginController controller,
  required SocialAuthService social,
}) async {
  switch (result) {
    case SocialAuthActive(:final session) || SocialAuthPending(:final session):
      // El controller adopta la sesión de Firebase ya abierta: guarda el
      // correo compartido y el perfil local igual que el ingreso con correo.
      AuthSession resolved = session;
      try {
        resolved = await controller.restoreSession() ?? session;
      } on AuthFailure catch (failure) {
        debugPrint('No se pudo adoptar la sesión social: ${failure.type}');
      }
      if (!context.mounted) return null;
      goToSessionHome(context, controller: controller, session: resolved);
      return null;
    case SocialAuthIncompleteProfile():
      Navigator.of(context).pushNamedAndRemoveUntil(
        AuthRoutes.completeProfile,
        (_) => false,
        arguments: CompleteProfileArgs(profile: result, social: social),
      );
      return null;
    case SocialAuthRejected(:final reason):
      Navigator.of(context).pushNamed(
        AuthRoutes.accountReview,
        arguments: AccountReviewArgs(
          email: '',
          rejected: true,
          rejectionReason: reason,
        ),
      );
      return null;
    case SocialAuthDisabled():
      return const AuthFailure(
        AuthFailureType.accountDisabled,
        'Tu cuenta está deshabilitada. Comunícate con el administrador.',
      );
    case SocialAuthCancelled():
      return null;
    case SocialAuthError(:final failure):
      return failure;
  }
}

/// Ruta inicial del rol, o "Cuenta en revisión" para un propietario
/// pendiente. Limpia la pila para no volver al login con "atrás".
void goToSessionHome(
  BuildContext context, {
  required LoginController controller,
  required AuthSession session,
}) {
  final route = controller.resolvePostLoginRoute(session);
  Navigator.of(context).pushNamedAndRemoveUntil(
    route,
    (_) => false,
    arguments: route == AuthRoutes.accountReview
        ? AccountReviewArgs(email: session.email)
        : null,
  );
}

/// Tras un conflicto de correo, ofrece vincular el proveedor pendiente una vez
/// que el usuario entró con su método original. [pendingBeforeSignIn] cubre
/// el ingreso social (el servicio limpia el pendiente al autenticar).
Future<void> offerPendingProviderLink(
  BuildContext context, {
  required SocialAuthService social,
  AuthProviderKind? pendingBeforeSignIn,
}) async {
  final kind = social.pendingLinkProvider ?? pendingBeforeSignIn;
  if (kind == null || social.linkedProviders.contains(kind)) return;
  final accepted = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('Vincular ${kind.displayName}'),
      content: Text(
        'Intentaste entrar con ${kind.displayName} usando este mismo correo. '
        '¿Quieres vincularlo para entrar también con ${kind.displayName}?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Ahora no'),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text('Vincular ${kind.displayName}'),
        ),
      ],
    ),
  );
  if (accepted != true || !context.mounted) return;
  String message;
  try {
    if (social.pendingLinkProvider == kind) {
      await social.linkPendingProvider();
    } else {
      await social.linkProvider(kind);
    }
    message = '${kind.displayName} quedó vinculado a tu cuenta.';
  } on AuthFailure catch (failure) {
    message = failure.message;
  }
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
