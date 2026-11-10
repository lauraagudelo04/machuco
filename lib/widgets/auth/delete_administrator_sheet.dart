import 'package:flutter/material.dart';
import 'package:machuco/controllers/auth/administrators_controller.dart';
import 'package:machuco/controllers/auth/login_controller.dart';
import 'package:machuco/core/design_system/design_system.dart';
import 'package:machuco/database/repository/auth/administrators_repository.dart';
import 'package:machuco/widgets/auth/auth_notice.dart';
import 'package:machuco/widgets/form/app_bottom_sheet.dart';

/// Resultado de la hoja: `deleted` si se anonimizó, `alreadyGone` si la cuenta
/// ya no existía (la lista ya se refrescó), `null` si se canceló.
enum DeleteAdministratorResult { deleted, alreadyGone }

/// Abre la hoja para eliminar (anonimizar) a OTRO administrador.
Future<DeleteAdministratorResult?> showDeleteAdministratorSheet(
  BuildContext context, {
  required AdministratorsController controller,
  required String uid,
  required String name,
}) {
  return AppBottomSheet.show<DeleteAdministratorResult>(
    context,
    title: 'Eliminar administrador',
    builder: (_) =>
        DeleteAdministratorSheet(controller: controller, uid: uid, name: name),
  );
}

class DeleteAdministratorSheet extends StatefulWidget {
  const DeleteAdministratorSheet({
    super.key,
    required this.controller,
    required this.uid,
    required this.name,
  });

  final AdministratorsController controller;
  final String uid;
  final String name;

  @override
  State<DeleteAdministratorSheet> createState() =>
      _DeleteAdministratorSheetState();
}

class _DeleteAdministratorSheetState extends State<DeleteAdministratorSheet> {
  static const _consequences = [
    'Su nombre, correo y celular se borran de la plataforma.',
    'Su cuenta pasa a "Administrador eliminado" y ya no puede ingresar.',
    'Se conservan su fecha de creación y las referencias en otros registros, '
        'sin identificarlo.',
  ];

  final _confirm = TextEditingController();
  String? _error;
  bool _canRetry = false;

  AdministratorsController get _controller => widget.controller;

  bool get _canSubmit =>
      _confirm.text.trim() == LoginController.deleteConfirmationText;

  @override
  void dispose() {
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_canSubmit || _controller.isSubmitting) return;
    setState(() {
      _error = null;
      _canRetry = false;
    });
    final ok = await _controller.anonymize(widget.uid);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(DeleteAdministratorResult.deleted);
      return;
    }
    switch (_controller.errorType) {
      case AdministratorsFailureType.notFound:
        Navigator.of(context).pop(DeleteAdministratorResult.alreadyGone);
        return;
      case AdministratorsFailureType.lastAdmin:
        setState(
          () => _error =
              'Es el único administrador activo. Crea otro administrador '
              'antes de eliminar esta cuenta.',
        );
      case AdministratorsFailureType.network:
        setState(() {
          _error = _controller.error;
          _canRetry = true;
        });
      default:
        setState(
          () => _error = _controller.error ?? 'No pudimos eliminar la cuenta.',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final busy = _controller.isSubmitting;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Vas a eliminar a ${widget.name}. Esta acción es definitiva. '
              'Se anonimizará su cuenta:',
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
                    Expanded(
                      child: Text(item, style: theme.textTheme.bodyMedium),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: AppSpacing.s2),
            const AuthNotice(
              message:
                  'Su correo seguirá ocupado: no podrá usarse para crear otra '
                  'cuenta.',
              tone: AuthNoticeTone.info,
            ),
            const SizedBox(height: AppSpacing.s3),
            AppTextField(
              label:
                  'Escribe ${LoginController.deleteConfirmationText} para '
                  'confirmar',
              controller: _confirm,
              enabled: !busy,
              textInputAction: TextInputAction.done,
              onChanged: (_) => setState(() {}),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.s3),
              AuthNotice(
                message: _error!,
                icon: _canRetry ? Icons.wifi_off_outlined : null,
                actionLabel: _canRetry ? 'Reintentar' : null,
                onAction: _canRetry ? _submit : null,
              ),
            ],
            const SizedBox(height: AppSpacing.s4),
            AppButton(
              key: const ValueKey('delete-administrator-submit'),
              label: 'Eliminar definitivamente',
              variant: AppButtonVariant.destructive,
              loading: busy,
              onPressed: _canSubmit ? _submit : null,
            ),
            const SizedBox(height: AppSpacing.s2),
            AppButton(
              label: 'Cancelar',
              variant: AppButtonVariant.secondary,
              onPressed: busy ? null : () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }
}
