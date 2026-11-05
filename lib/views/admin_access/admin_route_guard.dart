import 'package:flutter/material.dart';
import 'package:machuco/core/design_system/design_system.dart';
import 'package:machuco/models/auth/account_status.dart';
import 'package:machuco/models/auth/registered_user.dart';
import 'package:machuco/service/auth/auth_service.dart';
import 'package:machuco/service/auth/firebase_auth_service.dart';
import 'package:machuco/views/login/logout_navigation.dart';

/// Obtiene la sesión actual sin acoplar la vista a Firebase.
typedef AdminSessionLoader = Future<AuthSession?> Function();

/// Protege las rutas de administración: si la sesión no es de un
/// administrador activo redirige al login.
///
/// Esto es solo experiencia de usuario: la autorización real son las reglas
/// de `firestore.rules`.
class AdminRouteGuard extends StatefulWidget {
  const AdminRouteGuard({
    super.key,
    required this.child,
    this.sessionLoader,
    this.onDenied,
  });

  final Widget child;

  /// Por defecto restaura la sesión con `FirebaseAuthService`.
  final AdminSessionLoader? sessionLoader;

  /// Por defecto navega al login limpiando la pila.
  final void Function(BuildContext context)? onDenied;

  @override
  State<AdminRouteGuard> createState() => _AdminRouteGuardState();
}

enum _GuardState { checking, allowed, denied, failed }

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
      setState(
        () => _state = isAdmin ? _GuardState.allowed : _GuardState.denied,
      );
      if (!isAdmin) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          (widget.onDenied ?? goToLogin)(context);
        });
      }
    } on AuthFailure {
      if (!mounted) return;
      setState(() => _state = _GuardState.failed);
    }
  }

  @override
  Widget build(BuildContext context) {
    return switch (_state) {
      _GuardState.allowed => widget.child,
      _GuardState.checking => Scaffold(
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
