import 'package:flutter/material.dart';
import 'package:machuco/controllers/pqrs/pqrs_photo_controller.dart';
import 'package:machuco/core/design_system/design_system.dart';
import 'package:machuco/service/media/pqrs_photo_picker.dart';
import 'package:machuco/widgets/pqrs/pqrs_photo.dart';

/// Photo selector shared by the new-request form and the comment composer.
///
/// It shows the chosen photos, the "Adjuntar foto" button (camera or gallery)
/// and, under them, the validation message of the last rejected photo with the
/// accepted formats.
class PqrsPhotoPickerField extends StatelessWidget {
  const PqrsPhotoPickerField({
    super.key,
    required this.controller,
    this.label = 'Adjuntar foto',
  });

  final PqrsPhotoController controller;
  final String label;

  Future<void> _choose(BuildContext context) async {
    final origin = await showModalBottomSheet<PqrsPhotoOrigin>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Tomar foto'),
              onTap: () =>
                  Navigator.of(sheetContext).pop(PqrsPhotoOrigin.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Elegir de la galería'),
              onTap: () =>
                  Navigator.of(sheetContext).pop(PqrsPhotoOrigin.gallery),
            ),
          ],
        ),
      ),
    );
    if (origin != null) await controller.add(origin);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final error = controller.error;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (controller.photos.isNotEmpty) ...[
              PqrsPhotoStrip(
                attachments: controller.photos,
                onRemove: controller.remove,
              ),
              const SizedBox(height: AppSpacing.s3),
            ],
            AppButton(
              label: label,
              icon: Icons.add_a_photo_outlined,
              variant: AppButtonVariant.secondary,
              loading: controller.isPicking,
              onPressed: () => _choose(context),
            ),
            if (error != null) ...[
              const SizedBox(height: AppSpacing.s2),
              Semantics(
                liveRegion: true,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 16,
                      color: theme.colorScheme.error,
                    ),
                    const SizedBox(width: AppSpacing.s1),
                    Expanded(
                      child: Text(
                        error,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (error == pqrsFormatNotAllowedMessage)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.s1),
                  child: Text(
                    'Formatos aceptados: ${controller.acceptedFormats}.',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: context.appColors.textSecondary,
                    ),
                  ),
                ),
            ],
          ],
        );
      },
    );
  }
}
