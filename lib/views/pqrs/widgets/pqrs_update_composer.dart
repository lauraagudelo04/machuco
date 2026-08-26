import 'package:flutter/material.dart';

import '../../../core/design_system/components/app_button.dart';
import '../../../core/design_system/components/app_card.dart';
import '../../../core/design_system/components/app_text_field.dart';
import '../../../core/design_system/theme/app_theme_extensions.dart';
import '../../../core/design_system/tokens/app_spacing.dart';
import '../models/pqrs_models.dart';
import 'pqrs_photo.dart';

/// Composer used by the client and the owner to push a new trace entry.
///
/// Photo upload is simulated: there is no image picker dependency yet, so
/// "Adjuntar foto" creates a [PqrsAttachment.simulated] placeholder.
class PqrsUpdateComposer extends StatefulWidget {
  const PqrsUpdateComposer({
    super.key,
    required this.author,
    required this.title,
    required this.hint,
    required this.submitLabel,
    required this.onSubmit,
    this.secondaryLabel,
    this.secondaryIcon,
    this.onSecondary,
  });

  final PqrsActor author;
  final String title;
  final String hint;
  final String submitLabel;

  /// Receives the message and the simulated photos attached to it.
  final void Function(String message, List<PqrsAttachment> attachments) onSubmit;

  /// Optional second action, e.g. "Marcar como solucionada" or "Cerrar".
  final String? secondaryLabel;
  final IconData? secondaryIcon;
  final void Function(String message, List<PqrsAttachment> attachments)? onSecondary;

  @override
  State<PqrsUpdateComposer> createState() => _PqrsUpdateComposerState();
}

class _PqrsUpdateComposerState extends State<PqrsUpdateComposer> {
  final _controller = TextEditingController();
  final List<PqrsAttachment> _attachments = [];
  bool _validationAttempted = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String? get _messageError =>
      _validationAttempted && _controller.text.trim().isEmpty ? 'Escribe un mensaje' : null;

  void _attachPhoto() {
    setState(() {
      _attachments.add(
        PqrsAttachment.simulated(
          author: widget.author,
          label: 'evidencia-${_attachments.length + 1}.jpg',
        ),
      );
    });
  }

  void _run(void Function(String, List<PqrsAttachment>) action) {
    setState(() => _validationAttempted = true);
    final message = _controller.text.trim();
    if (message.isEmpty) return;

    action(message, List.of(_attachments));

    setState(() {
      _controller.clear();
      _attachments.clear();
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
            style: theme.textTheme.bodySmall
                ?.copyWith(color: context.appColors.textSecondary),
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
          if (_attachments.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.s4),
            PqrsPhotoStrip(
              attachments: _attachments,
              onRemove: (attachment) =>
                  setState(() => _attachments.remove(attachment)),
            ),
          ],
          const SizedBox(height: AppSpacing.s4),
          AppButton(
            label: 'Adjuntar foto',
            icon: Icons.add_a_photo_outlined,
            variant: AppButtonVariant.secondary,
            onPressed: _attachPhoto,
          ),
          const SizedBox(height: AppSpacing.s3),
          AppButton(
            label: widget.submitLabel,
            icon: Icons.send_outlined,
            onPressed: () => _run(widget.onSubmit),
          ),
          if (widget.onSecondary != null) ...[
            const SizedBox(height: AppSpacing.s3),
            AppButton(
              label: widget.secondaryLabel!,
              icon: widget.secondaryIcon,
              variant: AppButtonVariant.secondary,
              onPressed: () => _run(widget.onSecondary!),
            ),
          ],
        ],
      ),
    );
  }
}
