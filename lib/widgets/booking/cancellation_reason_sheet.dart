import 'package:flutter/material.dart';

import 'package:machuco/core/design_system/components/app_button.dart';
import 'package:machuco/core/design_system/components/app_dialog.dart';
import 'package:machuco/core/design_system/components/app_text_field.dart';
import 'package:machuco/core/design_system/theme/app_theme_extensions.dart';
import 'package:machuco/core/design_system/tokens/app_spacing.dart';

/// Flujo de cancelación compartido entre roles: primero pide confirmación
/// con [AppDialog.confirm] y, solo si se confirma, abre un bottom sheet que
/// exige un motivo obligatorio antes de invocar [onConfirm]. Nunca permite
/// confirmar con el motivo vacío.
///
/// Hoy lo consume Propietario (`owner_reservation_detail_page.dart`); queda
/// listo para que Cliente lo reutilice más adelante en su propio flujo de
/// cancelación sin duplicar esta lógica.
///
/// Devuelve `true` solo si el flujo completo terminó en una cancelación
/// confirmada (y ya se invocó y esperó [onConfirm]); `false` si el usuario
/// lo abandonó en cualquier paso.
Future<bool> showCancellationReasonSheet(
  BuildContext context, {
  required Future<void> Function(String reason) onConfirm,
  String confirmTitle = '¿Cancelar esta reserva?',
  String confirmMessage =
      'Esta acción no se puede deshacer y se notificará al cliente.',
}) async {
  final confirmed = await AppDialog.confirm(
    context,
    title: confirmTitle,
    message: confirmMessage,
    confirmLabel: 'Sí, cancelar',
    cancelLabel: 'Volver',
    destructive: true,
  );
  if (!confirmed || !context.mounted) return false;

  final reason = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const CancellationReasonSheet(),
  );
  if (reason == null || reason.trim().isEmpty || !context.mounted) {
    return false;
  }

  await onConfirm(reason.trim());
  return true;
}

/// Contenido del bottom sheet: campo de texto obligatorio para el motivo de
/// cancelación. Al confirmar hace `pop` con el texto ya recortado; bloquea
/// la confirmación mientras el campo esté vacío.
class CancellationReasonSheet extends StatefulWidget {
  const CancellationReasonSheet({super.key});

  @override
  State<CancellationReasonSheet> createState() =>
      _CancellationReasonSheetState();
}

class _CancellationReasonSheetState extends State<CancellationReasonSheet> {
  final _controller = TextEditingController();
  String? _errorText;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final reason = _controller.text.trim();
    if (reason.isEmpty) {
      setState(() => _errorText = 'El motivo de cancelación es obligatorio.');
      return;
    }
    Navigator.of(context).pop(reason);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.s5,
        AppSpacing.s2,
        AppSpacing.s5,
        AppSpacing.s5 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Motivo de cancelación',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: AppSpacing.s2),
          Text(
            'Este motivo quedará visible de forma permanente en el detalle '
            'de la reserva.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: context.appColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.s4),
          AppTextField(
            label: 'Motivo',
            controller: _controller,
            maxLines: 3,
            errorText: _errorText,
            onChanged: (_) {
              if (_errorText != null) setState(() => _errorText = null);
            },
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: AppSpacing.s5),
          AppButton(
            label: 'Confirmar cancelación',
            icon: Icons.block_outlined,
            variant: AppButtonVariant.destructive,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}
