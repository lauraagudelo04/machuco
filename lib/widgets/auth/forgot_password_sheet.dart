import 'package:flutter/material.dart';
import 'package:machuco/controllers/auth/login_controller.dart';
import 'package:machuco/controllers/auth/validators/auth_validators.dart';
import 'package:machuco/core/design_system/design_system.dart';
import 'package:machuco/service/auth/auth_service.dart';
import 'package:machuco/widgets/auth/auth_notice.dart';
import 'package:machuco/widgets/form/app_bottom_sheet.dart';

/// Mensaje neutro: no revela si el correo existe.
const passwordResetNeutralMessage =
    'Si el correo está registrado, recibirás instrucciones.';

Future<void> showForgotPasswordSheet(
  BuildContext context, {
  required LoginController controller,
  String initialEmail = '',
}) {
  return AppBottomSheet.show<void>(
    context,
    title: 'Recuperar contraseña',
    builder: (_) =>
        ForgotPasswordSheet(controller: controller, initialEmail: initialEmail),
  );
}

/// Contenido de la hoja de recuperación de contraseña.
class ForgotPasswordSheet extends StatefulWidget {
  const ForgotPasswordSheet({
    super.key,
    required this.controller,
    this.initialEmail = '',
  });

  final LoginController controller;
  final String initialEmail;

  @override
  State<ForgotPasswordSheet> createState() => _ForgotPasswordSheetState();
}

class _ForgotPasswordSheetState extends State<ForgotPasswordSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;
  bool _sent = false;
  AuthFailure? _failure;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() => _failure = null);
    try {
      await widget.controller.requestPasswordReset(
        email: _emailController.text,
      );
      if (!mounted) return;
      setState(() => _sent = true);
    } on AuthFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _failure = failure;
        _sent = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final cooldown = controller.resetCooldownSeconds;
        final loading = controller.isRequestingPasswordReset;
        final label = cooldown > 0
            ? 'Reenviar en ${cooldown}s'
            : 'Enviar instrucciones';
        return Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Escribe el correo de tu cuenta y te enviaremos un enlace '
                'para crear una contraseña nueva.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: context.appColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.s4),
              AppTextField(
                label: 'Correo electrónico',
                hint: 'correo@ejemplo.com',
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.email],
                validator: AuthValidators.email,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                onSubmitted: (_) => _submit(),
              ),
              if (_sent) ...[
                const SizedBox(height: AppSpacing.s3),
                const AuthNotice(
                  tone: AuthNoticeTone.info,
                  icon: Icons.mark_email_read_outlined,
                  message: passwordResetNeutralMessage,
                ),
              ],
              if (_failure != null) ...[
                const SizedBox(height: AppSpacing.s3),
                AuthNotice(
                  message: _failure!.message,
                  icon: _failure!.type == AuthFailureType.network
                      ? Icons.wifi_off_outlined
                      : Icons.error_outline,
                  actionLabel: _failure!.type == AuthFailureType.network
                      ? 'Reintentar'
                      : null,
                  onAction: _failure!.type == AuthFailureType.network
                      ? _submit
                      : null,
                ),
              ],
              const SizedBox(height: AppSpacing.s4),
              AppButton(
                label: label,
                loading: loading,
                onPressed: cooldown > 0 ? null : _submit,
              ),
              const SizedBox(height: AppSpacing.s2),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                child: const Text('Cerrar'),
              ),
            ],
          ),
        );
      },
    );
  }
}
