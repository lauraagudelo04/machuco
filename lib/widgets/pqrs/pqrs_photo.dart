import 'package:flutter/material.dart';
import 'package:machuco/core/design_system/design_system.dart';
import 'package:machuco/models/pqrs/pqrs.dart';
import 'package:machuco/widgets/pqrs/pqrs_presentation.dart';

/// Side of a photo tile.
const _tileSize = 88.0;

/// Thumbnail of a photo.
///
/// It draws the real image when the attachment carries its bytes and a neutral
/// placeholder otherwise (photos are only downloaded in the detail, and never
/// from the network: the bytes come from Firestore or the local queue).
class PqrsPhotoTile extends StatelessWidget {
  const PqrsPhotoTile({super.key, required this.attachment, this.size});

  final PqrsAttachment attachment;
  final double? size;

  @override
  Widget build(BuildContext context) {
    final side = size ?? _tileSize;
    final colors = context.appColors;
    final bytes = attachment.bytes;
    final placeholder = ColoredBox(
      color: colors.mediaFallback,
      child: Center(
        child: Icon(
          Icons.image_outlined,
          color: colors.textSecondary,
          size: side * .35,
        ),
      ),
    );

    return Semantics(
      label:
          'Foto ${attachment.label}, adjuntada por ${attachment.author.label}',
      image: true,
      child: ExcludeSemantics(
        child: Tooltip(
          message: '${attachment.label} · ${attachment.author.label}',
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: SizedBox(
              width: side,
              height: side,
              child: bytes == null
                  ? placeholder
                  : Image.memory(
                      bytes,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                      errorBuilder: (_, _, _) => placeholder,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Horizontal strip of photos. With [onRemove] each tile gets a remove button.
class PqrsPhotoStrip extends StatelessWidget {
  const PqrsPhotoStrip({super.key, required this.attachments, this.onRemove});

  final List<PqrsAttachment> attachments;
  final ValueChanged<PqrsAttachment>? onRemove;

  @override
  Widget build(BuildContext context) {
    if (attachments.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: _tileSize + AppSpacing.s1,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: attachments.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.s2),
        itemBuilder: (context, index) {
          final attachment = attachments[index];
          if (onRemove == null) return PqrsPhotoTile(attachment: attachment);
          return Stack(
            clipBehavior: Clip.none,
            children: [
              PqrsPhotoTile(attachment: attachment),
              Positioned(
                top: -AppSpacing.s3,
                right: -AppSpacing.s3,
                child: IconButton(
                  tooltip: 'Quitar ${attachment.label}',
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
