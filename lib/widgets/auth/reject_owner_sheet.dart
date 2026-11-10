import 'package:flutter/material.dart';
import 'package:machuco/controllers/auth/validators/auth_validators.dart';
import 'package:machuco/core/design_system/design_system.dart';
import 'package:machuco/widgets/form/app_bottom_sheet.dart';

/// Pide el motivo del rechazo. Devuelve el motivo ya validado o `null` si se
/// cancela.
Future<String?> showRejectOwnerSheet(BuildContext context) {
  return AppBottomSheet.show<String>(
    context,
    title: 'Rechazar solicitud',
    builder: (_) => const RejectOwnerSheet(),
  );
}

class RejectOwnerSheet extends StatefulWidget {
  const RejectOwnerSheet({super.key});

  @override
  State<RejectOwnerSheet> createState() => _RejectOwnerSheetState();
}

class _RejectOwnerSheetState extends State<RejectOwnerSheet> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      Navigator.of(context).pop(_reasonController.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'El propietario verá este motivo al intentar iniciar sesión.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: context.appColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.s3),
          AppTextField(
            label: 'Motivo del rechazo',
            hint: 'Entre 10 y 300 caracteres',
            controller: _reasonController,
            maxLines: 4,
            validator: AuthValidators.rejectionReason,
            autovalidateMode: AutovalidateMode.onUserInteraction,
          ),
          const SizedBox(height: AppSpacing.s4),
          AppButton(
            label: 'Confirmar rechazo',
            variant: AppButtonVariant.destructive,
            onPressed: _submit,
          ),
          const SizedBox(height: AppSpacing.s2),
          AppButton(
            label: 'Cancelar',
            variant: AppButtonVariant.secondary,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}
