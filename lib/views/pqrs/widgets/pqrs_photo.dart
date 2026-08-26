import 'package:flutter/material.dart';

import '../../../core/design_system/theme/app_theme_extensions.dart';
import '../../../core/design_system/tokens/app_radius.dart';
import '../../../core/design_system/tokens/app_spacing.dart';
import '../models/pqrs_models.dart';

/// Placeholder for a simulated photo.
///
/// The project has no image picker yet, so every attachment renders as a
/// deterministic gradient derived from [PqrsAttachment.seed]. Replacing this
/// widget with a real `Image` is the only change needed once uploads exist.
class PqrsPhotoTile extends StatelessWidget {
  const PqrsPhotoTile({super.key, required this.attachment, this.size = 88});

  final PqrsAttachment attachment;
  final double size;

  @override
  Widget build(BuildContext context) {
    final hue = (attachment.seed % 360).toDouble();
    final base = HSLColor.fromAHSL(1, hue, .45, .62).toColor();
    final tint = HSLColor.fromAHSL(1, (hue + 40) % 360, .5, .48).toColor();

    return Semantics(
      label: 'Foto ${attachment.label}, adjuntada por ${attachment.author.label}',
      image: true,
      child: ExcludeSemantics(
        child: Tooltip(
          message: '${attachment.label} · ${attachment.author.label}',
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.md),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [base, tint],
              ),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Center(
                  child: Icon(
                    Icons.photo_camera_back_outlined,
                    color: Colors.white.withValues(alpha: .85),
                    size: size * .3,
                  ),
                ),
                Align(
                  alignment: Alignment.bottomLeft,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.s1,
                      vertical: 2,
                    ),
                    color: Colors.black.withValues(alpha: .35),
                    child: Text(
                      attachment.author.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Horizontal strip of simulated photos.
class PqrsPhotoStrip extends StatelessWidget {
  const PqrsPhotoStrip({super.key, required this.attachments, this.onRemove});

  final List<PqrsAttachment> attachments;
  final ValueChanged<PqrsAttachment>? onRemove;

  @override
  Widget build(BuildContext context) {
    if (attachments.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: attachments.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.s2),
        itemBuilder: (context, index) {
          final attachment = attachments[index];
          if (onRemove == null) return PqrsPhotoTile(attachment: attachment);
          return Stack(
            children: [
              PqrsPhotoTile(attachment: attachment),
              Positioned(
                top: -6,
                right: -6,
                child: IconButton(
                  tooltip: 'Quitar ${attachment.label}',
                  iconSize: 18,
                  onPressed: () => onRemove!(attachment),
                  icon: const Icon(Icons.cancel),
                  color: context.appColors.textSecondary,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
