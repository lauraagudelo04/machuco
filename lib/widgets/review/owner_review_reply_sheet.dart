import 'package:flutter/material.dart';
import 'package:machuco/core/design_system/design_system.dart';
import 'package:machuco/models/review/review.dart';

/// Hoja con un campo de texto que usa el propietario para responder una
/// reseña o, con [OwnerReviewReplySheet.report], para reportarla.
class OwnerReviewReplySheet extends StatefulWidget {
  const OwnerReviewReplySheet({
    super.key,
    required this.review,
    required this.onSubmit,
  }) : title = 'Responder reseña',
       description = null,
       fieldLabel = 'Respuesta',
       hint = 'Agradece o aclara la situación...',
       submitLabel = 'Publicar',
       prefillReply = true;

  /// Variante para reportar la reseña al administrador.
  const OwnerReviewReplySheet.report({
    super.key,
    required this.review,
    required this.onSubmit,
  }) : title = 'Reportar reseña',
       description =
           'El administrador revisará la reseña y decidirá si la oculta.',
       fieldLabel = 'Motivo del reporte',
       hint = 'Ej.: lenguaje ofensivo, información falsa...',
       submitLabel = 'Enviar reporte',
       prefillReply = false;

  final Review review;
  final ValueChanged<String> onSubmit;
  final String title;

  /// Texto bajo el título; `null` usa el aviso de respuesta pública.
  final String? description;
  final String fieldLabel;
  final String hint;
  final String submitLabel;

  /// Si es `true`, el campo arranca con la respuesta actual del propietario.
  final bool prefillReply;

  @override
  State<OwnerReviewReplySheet> createState() => _OwnerReviewReplySheetState();
}

class _OwnerReviewReplySheetState extends State<OwnerReviewReplySheet> {
  late final TextEditingController _replyController;

  @override
  void initState() {
    super.initState();
    _replyController = TextEditingController(
      text: widget.prefillReply ? widget.review.ownerReply ?? '' : '',
    );
  }

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  void _submit() {
    final reply = _replyController.text.trim();
    if (reply.isEmpty) return;
    widget.onSubmit(reply);
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
              widget.title,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.s2),
            Text(
              widget.description ??
                  'Tu respuesta será visible públicamente para ${widget.review.authorName}.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: context.appColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.s4),
            AppTextField(
              label: widget.fieldLabel,
              controller: _replyController,
              hint: widget.hint,
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
                  child: AppButton(
                    label: widget.submitLabel,
                    onPressed: _submit,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
