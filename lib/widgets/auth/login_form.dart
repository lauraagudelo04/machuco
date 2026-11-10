import 'package:flutter/material.dart';
import 'package:machuco/controllers/auth/validators/auth_validators.dart';
import 'package:machuco/core/design_system/design_system.dart';
import 'package:machuco/widgets/auth/auth_password_field.dart';

/// Formulario de inicio de sesión. No conoce el controlador: recibe los
/// controladores de texto y los callbacks por parámetro.
class LoginForm extends StatelessWidget {
  const LoginForm({
    super.key,
    required this.emailController,
    required this.passwordController,
    required this.submitting,
    required this.onForgotPassword,
    required this.onSubmit,
    required this.onRegisterTap,
    this.socialButtons,
    this.notice,
    this.rememberEmail = false,
    this.onRememberEmailChanged,
  });

  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool submitting;
  final VoidCallback onForgotPassword;
  final VoidCallback onSubmit;
  final VoidCallback onRegisterTap;

  /// "Continuar con Google/GitHub".
  final Widget? socialButtons;

  /// Aviso en línea (error de la última solicitud), si lo hay.
  final Widget? notice;

  /// Casilla "Recordar mi correo" (no aplica al ingreso social).
  final bool rememberEmail;
  final ValueChanged<bool>? onRememberEmailChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AutofillGroup(
      key: const ValueKey('login-form'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (notice != null) ...[
                  notice!,
                  const SizedBox(height: AppSpacing.s4),
                ],
                AppTextField(
                  label: 'Correo electrónico',
                  hint: 'correo@ejemplo.com',
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
                  validator: AuthValidators.email,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                ),
                const SizedBox(height: AppSpacing.s4),
                AuthPasswordField(
                  controller: passwordController,
                  hint: 'Tu contraseña',
                  textInputAction: TextInputAction.done,
                  validator: AuthValidators.password,
                  onSubmitted: (_) => onSubmit(),
                ),
                CheckboxListTile(
                  key: const ValueKey('remember-email'),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  dense: true,
                  value: rememberEmail,
                  title: const Text('Recordar mi correo'),
                  onChanged: submitting || onRememberEmailChanged == null
                      ? null
                      : (value) => onRememberEmailChanged!(value ?? false),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: onForgotPassword,
                    style: TextButton.styleFrom(
                      minimumSize: const Size(48, 48),
                    ),
                    child: const Text('¿Olvidaste tu contraseña?'),
                  ),
                ),
                AppButton(
                  label: 'Ingresar',
                  loading: submitting,
                  onPressed: onSubmit,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.s4),
          ?socialButtons,
          const SizedBox(height: AppSpacing.s2),
          Text.rich(
            TextSpan(
              text: '¿No tienes cuenta? ',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: context.appColors.textSecondary,
              ),
              children: [
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: InkWell(
                    onTap: onRegisterTap,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 48),
                      child: Center(
                        widthFactor: 1,
                        child: Text(
                          'Regístrate aquí',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
