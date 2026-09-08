import 'package:flutter/material.dart';
import '../../core/design_system/design_system.dart';
import 'package:machuco/models/review/review.dart';
import 'star_rating_selector.dart';

class AddReviewSheet extends StatefulWidget {
  final void Function(Review review) onSave;

  const AddReviewSheet({super.key, required this.onSave});

  static Future<void> show(
    BuildContext context, {
    required void Function(Review review) onSave,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => AddReviewSheet(onSave: onSave),
    );
  }

  @override
  State<AddReviewSheet> createState() => _AddReviewSheetState();
}

class _AddReviewSheetState extends State<AddReviewSheet> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  int _rating = 0;
  bool _submitted = false;

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  void _save() {
    setState(() => _submitted = true);
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();
    if (_rating == 0 || title.isEmpty || body.isEmpty) return;

    widget.onSave(
      Review(
        author: 'Tú',
        title: title,
        body: body,
        rating: _rating,
        date: DateTime.now(),
      ),
    );

    if (!context.mounted) return;
    Navigator.of(context).pop();
  }

  String? get _ratingError =>
      _submitted && _rating == 0 ? 'Selecciona una calificación' : null;
  String? get _titleError =>
      _submitted && _titleController.text.trim().isEmpty ? 'Campo requerido' : null;
  String? get _bodyError =>
      _submitted && _bodyController.text.trim().isEmpty ? 'Campo requerido' : null;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final theme = Theme.of(context);

    return Theme(
      data: theme.copyWith(
        inputDecorationTheme: theme.inputDecorationTheme.copyWith(
          fillColor: theme.colorScheme.surface,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: BorderSide(color: context.appColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: const BorderSide(color: AppColors.violet, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: const BorderSide(color: AppColors.rose),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: const BorderSide(color: AppColors.rose, width: 1.5),
          ),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.s5,
          AppSpacing.s1,
          AppSpacing.s5,
          AppSpacing.s6 + bottomInset,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Añadir reseña',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.s4),
              StarRatingSelector(
                onChanged: (v) => setState(() => _rating = v),
              ),
              if (_ratingError != null) ...[
                const SizedBox(height: AppSpacing.s2),
                Text(
                  _ratingError!,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: AppSpacing.s5),
              AppTextField(
                label: 'Título',
                controller: _titleController,
                hint: 'Ej. Excelente estadía...',
                errorText: _titleError,
                onChanged: (_) {
                  if (_submitted) setState(() {});
                },
              ),
              const SizedBox(height: AppSpacing.s4),
              AppTextField(
                label: 'Tu reseña',
                controller: _bodyController,
                hint: 'Cuéntanos tu experiencia...',
                errorText: _bodyError,
                maxLines: 4,
                onChanged: (_) {
                  if (_submitted) setState(() {});
                },
              ),
              const SizedBox(height: AppSpacing.s6),
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      label: 'Cancelar',
                      variant: AppButtonVariant.secondary,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s3),
                  Expanded(
                    child: AppButton(
                      label: 'Guardar',
                      variant: AppButtonVariant.primary,
                      onPressed: _save,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}