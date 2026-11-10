import 'package:flutter/material.dart';
import 'package:machuco/controllers/auth/administrators_controller.dart';
import 'package:machuco/controllers/auth/validators/auth_validators.dart';
import 'package:machuco/core/design_system/design_system.dart';
import 'package:machuco/service/auth/auth_service.dart';
import 'package:machuco/views/admin_access/administrators_factory.dart';
import 'package:machuco/views/login/logout_navigation.dart';
import 'package:machuco/widgets/auth/auth_notice.dart';
import 'package:machuco/widgets/auth/auth_password_field.dart';
import 'package:machuco/widgets/layout/responsive_content.dart';

/// Primer ingreso de un administrador creado con contraseña temporal: debe
/// definir una nueva. No se puede abandonar con "atrás"; solo cerrando sesión.
class AdminChangePasswordPage extends StatefulWidget {
  const AdminChangePasswordPage({
    super.key,
    required this.homeRoute,
    this.controller,
    this.onLogout,
  });

  /// Ruta inicial del administrador, a la que se va al terminar.
  final String homeRoute;

  /// Si es `null` se crea el de producción y esta página lo libera.
  final AdministratorsController? controller;

  /// Por defecto cierra sesión y va al login.
  final VoidCallback? onLogout;

  @override
  State<AdminChangePasswordPage> createState() =>
      _AdminChangePasswordPageState();
}

class _AdminChangePasswordPageState extends State<AdminChangePasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  late final AdministratorsController _controller;
  late final bool _ownsController;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? buildAdministratorsController();
  }

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_controller.isChangingPassword) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final ok = await _controller.changeOwnPassword(
      newPassword: _password.text,
      confirmation: _confirm.text,
    );
    if (!mounted || !ok) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Contraseña actualizada.')));
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(widget.homeRoute, (_) => false);
  }

  void _logout() {
    final onLogout = widget.onLogout;
    if (onLogout != null) {
      onLogout();
    } else {
      logoutAndGoToLogin(context);
    }
  }

  Widget? _buildNotice() {
    final message = _controller.error;
    final failure = _controller.passwordFailure;
    if (message == null || failure == null) return null;
    switch (failure) {
      case AuthFailureType.requiresRecentLogin:
        return AuthNotice(
          message:
              'Por seguridad, vuelve a iniciar sesión con tu contraseña '
              'temporal e inténtalo de nuevo.',
          icon: Icons.lock_reset_outlined,
          actionLabel: 'Iniciar sesión de nuevo',
          onAction: _logout,
        );
      case AuthFailureType.network:
        return AuthNotice(
          message: message,
          icon: Icons.wifi_off_outlined,
          actionLabel: 'Reintentar',
          onAction: _submit,
        );
      default:
        return AuthNotice(message: message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text('Define tu contraseña'),
          actions: [
            TextButton(
              onPressed: _logout,
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              child: const Text('Cerrar sesión'),
            ),
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            child: ResponsiveContent(
              maxWidth: 560,
              padding: const EdgeInsets.all(AppSpacing.s4),
              child: ListenableBuilder(
                listenable: _controller,
                builder: (context, _) {
                  final busy = _controller.isChangingPassword;
                  final notice = _buildNotice();
                  return Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Ingresaste con una contraseña temporal. Para '
                          'continuar, define una contraseña nueva.',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: context.appColors.textSecondary,
                              ),
                        ),
                        const SizedBox(height: AppSpacing.s4),
                        if (notice != null) ...[
                          notice,
                          const SizedBox(height: AppSpacing.s4),
                        ],
                        AuthPasswordField(
                          controller: _password,
                          label: 'Contraseña nueva',
                          hint:
                              'Mínimo ${AuthValidators.passwordMinLength} '
                              'caracteres',
                          autofillHints: const [AutofillHints.newPassword],
                          enabled: !busy,
                          validator: AuthValidators.password,
                        ),
                        const SizedBox(height: AppSpacing.s4),
                        AuthPasswordField(
                          controller: _confirm,
                          label: 'Confirmar contraseña',
                          hint: 'Repite tu contraseña',
                          textInputAction: TextInputAction.done,
                          autofillHints: const [AutofillHints.newPassword],
                          enabled: !busy,
                          validator: AuthValidators.confirmPassword(
                            () => _password.text,
                          ),
                          onSubmitted: (_) => _submit(),
                        ),
                        const SizedBox(height: AppSpacing.s5),
                        AppButton(
                          label: 'Guardar contraseña',
                          loading: busy,
                          onPressed: _submit,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
