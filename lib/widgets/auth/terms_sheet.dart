import 'package:flutter/material.dart';
import 'package:machuco/core/design_system/design_system.dart';
import 'package:machuco/widgets/form/app_bottom_sheet.dart';

/// Enlace "Términos y condiciones". Abre una hoja con texto provisional; no
/// bloquea el registro.
class TermsLink extends StatelessWidget {
  const TermsLink({super.key});

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () => showTermsSheet(context),
      style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
      child: const Text('Términos y condiciones'),
    );
  }
}

Future<void> showTermsSheet(BuildContext context) {
  return AppBottomSheet.show<void>(
    context,
    title: 'Términos y condiciones',
    builder: (sheetContext) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Contenido de términos y condiciones pendiente',
          style: Theme.of(sheetContext).textTheme.bodyMedium?.copyWith(
            color: sheetContext.appColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.s4),
        AppButton(
          label: 'Cerrar',
          variant: AppButtonVariant.secondary,
          onPressed: () => Navigator.of(sheetContext).pop(),
        ),
      ],
    ),
  );
}
