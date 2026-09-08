import 'package:flutter/material.dart';
import 'package:machuco/controllers/review/review_administration_controller.dart';
import 'package:machuco/core/design_system/design_system.dart';

class ReviewReplySheet extends StatefulWidget {
  const ReviewReplySheet({super.key, required this.entry, required this.onSubmit});

  final AdminReviewEntry entry;
  final ValueChanged<String> onSubmit;

  @override
  State<ReviewReplySheet> createState() => _ReviewReplySheetState();
}

class _ReviewReplySheetState extends State<ReviewReplySheet> {
  late final TextEditingController _replyController;

  @override
  void initState() {
    super.initState();
    _replyController = TextEditingController(
      text: widget.entry.adminReply ?? '',
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
              'Responder reseña',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.s2),
            Text(
              'Tu respuesta será visible públicamente para ${widget.entry.review.author}.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: context.appColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.s4),
            AppTextField(
              label: 'Respuesta',
              controller: _replyController,
              hint: 'Escribe una respuesta profesional...',
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
                  child: AppButton(label: 'Publicar', onPressed: _submit),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
