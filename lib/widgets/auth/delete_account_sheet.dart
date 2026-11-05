import 'package:flutter/material.dart';
import 'package:machuco/controllers/auth/login_controller.dart';
import 'package:machuco/core/design_system/design_system.dart';
import 'package:machuco/service/auth/auth_service.dart';
import 'package:machuco/widgets/auth/auth_notice.dart';
import 'package:machuco/widgets/auth/auth_password_field.dart';
import 'package:machuco/widgets/form/app_bottom_sheet.dart';

/// Abre la hoja "Eliminar cuenta". Devuelve `true` si la cuenta se eliminó;
/// entonces quien llama debe navegar al login limpiando la pila.
Future<bool> showDeleteAccountSheet(
  BuildContext context, {
  required LoginController controller,
}) async {
  final deleted = await AppBottomSheet.show<bool>(
    context,
    title: 'Eliminar cuenta',
    builder: (_) => DeleteAccountSheet(controller: controller),
  );
  return deleted ?? false;
}

/// Contenido de la hoja de eliminación de cuenta (acción irreversible).
class DeleteAccountSheet extends StatefulWidget {
  const DeleteAccountSheet({super.key, required this.controller});

  final LoginController controller;

  @override
  State<DeleteAccountSheet> createState() => _DeleteAccountSheetState();
}

class _DeleteAccountSheetState extends State<DeleteAccountSheet> {
  static const _consequences = [
    'Tu perfil y tus datos personales.',
    'El acceso con tu correo y contraseña.',
    'Los datos guardados en este dispositivo.',
  ];

  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _submitting = false;
  String? _errorMessage;

  bool get _canSubmit =>
      _passwordController.text.isNotEmpty &&
      _confirmController.text.trim() == LoginController.deleteConfirmationText;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_canSubmit || _submitting) return;
    setState(() {
      _submitting = true;
      _errorMessage = null;
    });
    try {
      await widget.controller.deleteAccount(
        password: _passwordController.text,
        confirmationText: _confirmController.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on AuthFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _errorMessage = failure.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Esta acción es definitiva y no se puede deshacer. Se eliminará:',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: context.appColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.s2),
        for (final item in _consequences)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.s1),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.remove_circle_outline,
                  size: AppSpacing.s4,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(width: AppSpacing.s2),
                Expanded(child: Text(item, style: theme.textTheme.bodyMedium)),
              ],
            ),
          ),
        const SizedBox(height: AppSpacing.s3),
        AuthPasswordField(
          controller: _passwordController,
          label: 'Contraseña actual',
          autofillHints: const [AutofillHints.password],
          enabled: !_submitting,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: AppSpacing.s3),
        AppTextField(
          label:
              'Escribe ${LoginController.deleteConfirmationText} para confirmar',
          controller: _confirmController,
          enabled: !_submitting,
          textInputAction: TextInputAction.done,
          onChanged: (_) => setState(() {}),
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: AppSpacing.s3),
          AuthNotice(message: _errorMessage!),
        ],
        const SizedBox(height: AppSpacing.s4),
        AppButton(
          label: 'Eliminar definitivamente',
          variant: AppButtonVariant.destructive,
          loading: _submitting,
          onPressed: _canSubmit ? _submit : null,
        ),
        const SizedBox(height: AppSpacing.s2),
        AppButton(
          label: 'Cancelar',
          variant: AppButtonVariant.secondary,
          onPressed: _submitting
              ? null
              : () => Navigator.of(context).pop(false),
        ),
      ],
    );
  }
}
