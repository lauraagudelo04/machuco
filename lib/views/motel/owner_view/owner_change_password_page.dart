import 'package:flutter/material.dart';

import 'package:machuco/controllers/auth/validators/auth_validators.dart';
import 'package:machuco/controllers/owner_management/owner_profile_controller.dart';
import 'package:machuco/core/design_system/design_system.dart';
import 'package:machuco/widgets/auth/auth_notice.dart';
import 'package:machuco/widgets/auth/auth_password_field.dart';

/// Cambio de contraseña del propietario autenticado.
///
/// Sirve tanto para reemplazar la contraseña temporal con la que nace una
/// cuenta creada por el panel como para cambiarla cuando el propietario
/// quiera. Al terminar limpia `mustChangePassword` si estaba activo.
class OwnerChangePasswordPage extends StatefulWidget {
  const OwnerChangePasswordPage({super.key, this.controller});

  /// Controlador inyectable para los tests; si es `null` se crea uno propio.
  final OwnerProfileController? controller;

  @override
  State<OwnerChangePasswordPage> createState() =>
      _OwnerChangePasswordPageState();
}

class _OwnerChangePasswordPageState extends State<OwnerChangePasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmationController = TextEditingController();

  late final OwnerProfileController _controller;
  late final bool _ownsController;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? OwnerProfileController();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmationController.dispose();
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_controller.isChangingPassword) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();

    final changed = await _controller.changePassword(
      newPassword: _passwordController.text,
    );
    if (!mounted) return;

    if (!changed) {
      // El aviso en línea muestra el motivo (débil, sin conexión...).
      setState(() {});
      return;
    }
    Navigator.of(context).pop(true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Contraseña actualizada correctamente.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cambiar contraseña')),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) {
            final isSaving = _controller.isChangingPassword;
            final error = _controller.passwordError;
            final usesTemporary = _controller.profile?.mustChangePassword;

            return ListView(
              padding: const EdgeInsets.all(AppSpacing.screen),
              children: [
                if (usesTemporary == true) ...[
                  const AuthNotice(
                    message:
                        'Estás usando una contraseña temporal. Define una '
                        'nueva para asegurar tu cuenta.',
                    tone: AuthNoticeTone.info,
                  ),
                  const SizedBox(height: AppSpacing.s4),
                ],
                AppCard(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AuthPasswordField(
                          controller: _passwordController,
                          label: 'Nueva contraseña',
                          hint: 'Mínimo 8 caracteres',
                          enabled: !isSaving,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.newPassword],
                          validator: AuthValidators.password,
                        ),
                        const SizedBox(height: AppSpacing.s4),
                        AuthPasswordField(
                          controller: _confirmationController,
                          label: 'Confirmar contraseña',
                          enabled: !isSaving,
                          textInputAction: TextInputAction.done,
                          autofillHints: const [AutofillHints.newPassword],
                          validator: AuthValidators.confirmPassword(
                            () => _passwordController.text,
                          ),
                          onSubmitted: (_) => _submit(),
                        ),
                      ],
                    ),
                  ),
                ),
                if (error != null) ...[
                  const SizedBox(height: AppSpacing.s4),
                  AuthNotice(message: error),
                ],
                const SizedBox(height: AppSpacing.s6),
                AppButton(
                  label: 'Guardar contraseña',
                  icon: Icons.check_outlined,
                  loading: isSaving,
                  onPressed: isSaving ? null : _submit,
                ),
                const SizedBox(height: AppSpacing.s3),
                AppButton(
                  label: 'Cancelar',
                  variant: AppButtonVariant.secondary,
                  onPressed: isSaving
                      ? null
                      : () => Navigator.of(context).maybePop(),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
