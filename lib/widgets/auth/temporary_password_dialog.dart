import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:machuco/core/design_system/design_system.dart';
import 'package:machuco/widgets/auth/auth_notice.dart';

/// Muestra la contraseña temporal del administrador recién creado.
///
/// No se puede cerrar tocando fuera ni con "atrás": solo con "Listo". La
/// contraseña vive únicamente en este diálogo; no se guarda ni se registra.
Future<void> showTemporaryPasswordDialog(
  BuildContext context, {
  required String email,
  required String password,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => PopScope(
      canPop: false,
      child: TemporaryPasswordDialog(email: email, password: password),
    ),
  );
}

class TemporaryPasswordDialog extends StatefulWidget {
  const TemporaryPasswordDialog({
    super.key,
    required this.email,
    required this.password,
  });

  final String email;
  final String password;

  @override
  State<TemporaryPasswordDialog> createState() =>
      _TemporaryPasswordDialogState();
}

class _TemporaryPasswordDialogState extends State<TemporaryPasswordDialog> {
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.password));
    if (mounted) setState(() => _copied = true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Administrador creado'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Entrega esta contraseña temporal a ${widget.email}. No se envió '
              'ningún correo ni mensaje. En su primer ingreso deberá cambiarla.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.s3),
            AppCard(
              child: SelectableText(
                widget.password,
                key: const ValueKey('temporary-password'),
                style: theme.textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: AppSpacing.s3),
            const AuthNotice(
              message: 'No se volverá a mostrar. Cópiala antes de continuar.',
              tone: AuthNoticeTone.info,
              icon: Icons.visibility_off_outlined,
            ),
            const SizedBox(height: AppSpacing.s3),
            AppButton(
              label: _copied ? 'Contraseña copiada' : 'Copiar contraseña',
              icon: _copied ? Icons.check : Icons.copy_outlined,
              variant: AppButtonVariant.secondary,
              onPressed: _copy,
            ),
          ],
        ),
      ),
      actions: [
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Listo'),
        ),
      ],
    );
  }
}
