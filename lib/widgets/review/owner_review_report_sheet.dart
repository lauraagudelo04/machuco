import 'package:flutter/material.dart';
import 'package:machuco/core/design_system/design_system.dart';
import 'package:machuco/models/review/review.dart';

/// Hoja donde el propietario escribe el motivo para reportar una reseña al
/// administrador.
class OwnerReviewReportSheet extends StatefulWidget {
  const OwnerReviewReportSheet({
    super.key,
    required this.review,
    required this.onSubmit,
  });

  final Review review;
  final ValueChanged<String> onSubmit;

  @override
  State<OwnerReviewReportSheet> createState() => _OwnerReviewReportSheetState();
}

class _OwnerReviewReportSheetState extends State<OwnerReviewReportSheet> {
  late final TextEditingController _reasonController;

  @override
  void initState() {
    super.initState();
    _reasonController = TextEditingController();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  void _submit() {
    final reason = _reasonController.text.trim();
    if (reason.isEmpty) return;
    widget.onSubmit(reason);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.s5,
          AppSpacing.s1,
          AppSpacing.s5,
          AppSpacing.s6,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Reportar reseña',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.s2),
            Text(
              'El administrador revisará la reseña y decidirá si la oculta.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: context.appColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.s4),
            AppTextField(
              label: 'Motivo del reporte',
              controller: _reasonController,
              hint: 'Ej.: lenguaje ofensivo, información falsa...',
              maxLines: 4,
            ),
            const SizedBox(height: AppSpacing.s5),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: 'Cancelar',
                    variant: AppButtonVariant.secondary,
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                const SizedBox(width: AppSpacing.s3),
                Expanded(
                  child: AppButton(label: 'Enviar reporte', onPressed: _submit),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
