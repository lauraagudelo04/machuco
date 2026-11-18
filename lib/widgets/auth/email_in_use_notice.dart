import 'package:flutter/material.dart';
import 'package:machuco/core/design_system/design_system.dart';
import 'package:machuco/widgets/auth/auth_notice.dart';

/// Aviso del registro cuando el correo ya tiene cuenta (`email-already-in-use`):
/// ofrece ir a iniciar sesión o recuperar la contraseña con el correo escrito.
class EmailInUseNotice extends StatelessWidget {
  const EmailInUseNotice({
    super.key,
    required this.email,
    required this.onLogin,
    required this.onForgotPassword,
  });

  final String email;
  final VoidCallback onLogin;
  final VoidCallback onForgotPassword;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('email-in-use-notice'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AuthNotice(message: 'El correo $email ya tiene una cuenta.'),
        const SizedBox(height: AppSpacing.s2),
        Wrap(
          spacing: AppSpacing.s2,
          children: [
            TextButton(
              key: const ValueKey('email-in-use-login'),
              onPressed: onLogin,
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              child: const Text('Iniciar sesión'),
            ),
            TextButton(
              key: const ValueKey('email-in-use-forgot'),
              onPressed: onForgotPassword,
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              child: const Text('¿Olvidaste tu contraseña?'),
            ),
          ],
        ),
      ],
    );
  }
}
