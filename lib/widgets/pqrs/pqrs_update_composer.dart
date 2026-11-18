import 'package:flutter/material.dart';
import 'package:machuco/controllers/pqrs/pqrs_photo_controller.dart';
import 'package:machuco/core/design_system/design_system.dart';
import 'package:machuco/models/pqrs/pqrs.dart';
import 'package:machuco/utils/pqrs_validator.dart';
import 'package:machuco/widgets/pqrs/pqrs_photo_picker_field.dart';
import 'package:machuco/widgets/pqrs/pqrs_presentation.dart';

/// Result of an action started from the composer: `true` when it succeeded.
typedef PqrsComposerAction =
    Future<bool> Function(String message, List<PqrsAttachment> attachments);

/// Composer used by the client and the owner to push a new trace entry.
///
/// The text and the photos are cleared only when the action succeeds, so a
/// failed send keeps what the user wrote. Photos come from [photos].
class PqrsUpdateComposer extends StatefulWidget {
  const PqrsUpdateComposer({
    super.key,
    required this.author,
    required this.title,
    required this.hint,
    required this.submitLabel,
    required this.onSubmit,
    required this.photos,
    this.busy = false,
    this.secondaryLabel,
    this.secondaryIcon,
    this.onSecondary,
  });

  final PqrsActor author;
  final String title;
  final String hint;
  final String submitLabel;
  final PqrsPhotoController photos;

  /// True while the controller is sending; disables the buttons.
  final bool busy;

  final PqrsComposerAction onSubmit;

  /// Optional second action, e.g. "Marcar como solucionada".
  final String? secondaryLabel;
  final IconData? secondaryIcon;
  final PqrsComposerAction? onSecondary;

  @override
  State<PqrsUpdateComposer> createState() => _PqrsUpdateComposerState();
}

class _PqrsUpdateComposerState extends State<PqrsUpdateComposer> {
  final _controller = TextEditingController();
  bool _validationAttempted = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String? get _messageError =>
      _validationAttempted ? PqrsValidator.message(_controller.text) : null;

  Future<void> _run(PqrsComposerAction action) async {
    setState(() => _validationAttempted = true);
    if (PqrsValidator.message(_controller.text) != null) return;

    final succeeded = await action(
      _controller.text.trim(),
      widget.photos.photos,
    );
    if (!succeeded || !mounted) return;
    widget.photos.clear();
    setState(() {
      _controller.clear();
      _validationAttempted = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.title, style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.s1),
          Text(
            'Escribes como ${widget.author.label.toLowerCase()}.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: context.appColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.s4),
          AppTextField(
            label: 'Mensaje',
            controller: _controller,
            hint: widget.hint,
            maxLines: 4,
            errorText: _messageError,
            onChanged: (_) {
              if (_validationAttempted) setState(() {});
            },
          ),
          const SizedBox(height: AppSpacing.s4),
          PqrsPhotoPickerField(controller: widget.photos),
          const SizedBox(height: AppSpacing.s3),
          AppButton(
            label: widget.submitLabel,
            icon: Icons.send_outlined,
            loading: widget.busy,
            onPressed: () => _run(widget.onSubmit),
          ),
          if (widget.onSecondary != null) ...[
            const SizedBox(height: AppSpacing.s3),
            AppButton(
              label: widget.secondaryLabel!,
              icon: widget.secondaryIcon,
              variant: AppButtonVariant.secondary,
              onPressed: widget.busy ? null : () => _run(widget.onSecondary!),
            ),
          ],
        ],
      ),
    );
  }
}
