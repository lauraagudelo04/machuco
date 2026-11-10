import 'package:flutter/material.dart';
import 'package:machuco/controllers/auth/auth_routes.dart';
import 'package:machuco/core/design_system/design_system.dart';
import 'package:machuco/models/auth/account_status.dart';
import 'package:machuco/models/auth/registered_user.dart';
import 'package:machuco/service/auth/auth_service.dart';
import 'package:machuco/service/auth/firebase_auth_service.dart';
import 'package:machuco/views/login/logout_navigation.dart';

/// Obtiene la sesión actual sin acoplar la vista a Firebase.
typedef AdminSessionLoader = Future<AuthSession?> Function();

/// Protege las rutas de administración: si la sesión no es de un
/// administrador activo redirige al login. Un administrador que aún debe
/// cambiar su contraseña temporal (`mustChangePassword`) va a
/// [AuthRoutes.adminChangePassword], también al restaurar la sesión.
///
/// Esto es solo experiencia de usuario: la autorización real son las reglas
/// de `firestore.rules`.
class AdminRouteGuard extends StatefulWidget {
  const AdminRouteGuard({
    super.key,
    required this.child,
    this.sessionLoader,
    this.onDenied,
    this.allowPendingPasswordChange = false,
    this.onPasswordChangeRequired,
  });

  final Widget child;

  /// Por defecto restaura la sesión con `FirebaseAuthService`.
  final AdminSessionLoader? sessionLoader;

  /// Por defecto navega al login limpiando la pila.
  final void Function(BuildContext context)? onDenied;

  /// `true` solo en la pantalla de cambio de contraseña: sin esto el guard
  /// la redirigiría a sí misma en bucle.
  final bool allowPendingPasswordChange;

  /// Por defecto navega a [AuthRoutes.adminChangePassword] limpiando la pila.
  final void Function(BuildContext context)? onPasswordChangeRequired;

  @override
  State<AdminRouteGuard> createState() => _AdminRouteGuardState();
}

enum _GuardState { checking, allowed, denied, passwordChange, failed }

class _AdminRouteGuardState extends State<AdminRouteGuard> {
  _GuardState _state = _GuardState.checking;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    setState(() => _state = _GuardState.checking);
    try {
      final loader =
          widget.sessionLoader ?? FirebaseAuthService().restoreSession;
      final session = await loader();
      if (!mounted) return;
      final isAdmin =
          session != null &&
          session.role == RegisteredUserRole.admin &&
          session.accountStatus == AccountStatus.active;
      final mustChange =
          isAdmin &&
          !widget.allowPendingPasswordChange &&
          session.profile?.mustChangePassword == true;
      setState(
        () => _state = !isAdmin
            ? _GuardState.denied
            : mustChange
            ? _GuardState.passwordChange
            : _GuardState.allowed,
      );
      if (!isAdmin || mustChange) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (mustChange) {
            (widget.onPasswordChangeRequired ?? _goToChangePassword)(context);
          } else {
            (widget.onDenied ?? goToLogin)(context);
          }
        });
      }
    } on AuthFailure {
      if (!mounted) return;
      setState(() => _state = _GuardState.failed);
    }
  }

  void _goToChangePassword(BuildContext context) {
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AuthRoutes.adminChangePassword, (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    return switch (_state) {
      _GuardState.allowed => widget.child,
      _GuardState.checking || _GuardState.passwordChange => Scaffold(
        body: Center(
          child: Semantics(
            label: 'Verificando acceso',
            child: const CircularProgressIndicator(),
          ),
        ),
      ),
      _GuardState.denied => const Scaffold(
        body: AppEmptyState(
          icon: Icons.lock_outline,
          title: 'Acceso restringido',
          message: 'Esta sección es solo para administradores.',
        ),
      ),
      _GuardState.failed => Scaffold(
        body: AppErrorState(
          message: 'No pudimos verificar tu acceso. Revisa tu conexión.',
          onRetry: _check,
        ),
      ),
    };
  }
}
