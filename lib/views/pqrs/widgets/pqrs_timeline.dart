import 'package:flutter/material.dart';

import '../../../core/design_system/theme/app_theme_extensions.dart';
import '../../../core/design_system/tokens/app_radius.dart';
import '../../../core/design_system/tokens/app_spacing.dart';
import '../models/pqrs_models.dart';
import 'pqrs_photo.dart';

/// Chronological traceability of a request: who wrote, when, with which photos
/// and which status change it produced.
///
/// The same timeline is used by the three profiles; the administrator simply
/// renders it without any composer below.
class PqrsTimeline extends StatelessWidget {
  const PqrsTimeline({super.key, required this.request});

  final PqrsRequest request;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final opening = PqrsTraceEntry(
      id: '${request.id}-opening',
      author: PqrsActor.client,
      message: request.description,
      createdAt: request.createdAt,
      attachments: request.attachments,
      statusChange: PqrsStatus.pending,
    );

    final entries = [opening, ...request.trace];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Trazabilidad', style: theme.textTheme.titleLarge),
        const SizedBox(height: AppSpacing.s1),
        Text(
          '${entries.length} ${entries.length == 1 ? 'movimiento' : 'movimientos'} registrados',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: context.appColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.s4),
        for (var index = 0; index < entries.length; index++)
          _TimelineTile(
            entry: entries[index],
            isFirst: index == 0,
            isLast: index == entries.length - 1,
          ),
      ],
    );
  }
}

class _TimelineTile extends StatelessWidget {
  const _TimelineTile({
    required this.entry,
    required this.isFirst,
    required this.isLast,
  });

  final PqrsTraceEntry entry;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = entry.author.color;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Rail(accent: accent, icon: entry.author.icon, isFirst: isFirst, isLast: isLast),
          const SizedBox(width: AppSpacing.s3),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : AppSpacing.s5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        entry.author.label,
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(width: AppSpacing.s2),
                      Text(
                        formatPqrsDateTime(entry.createdAt),
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: context.appColors.textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.s2),
                  Text(
                    entry.message,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: context.appColors.textSecondary),
                  ),
                  if (entry.attachments.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.s3),
                    PqrsPhotoStrip(attachments: entry.attachments),
                  ],
                  if (entry.statusChange != null) ...[
                    const SizedBox(height: AppSpacing.s3),
                    _StatusChangeChip(status: entry.statusChange!),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Rail extends StatelessWidget {
  const _Rail({
    required this.accent,
    required this.icon,
    required this.isFirst,
    required this.isLast,
  });

  final Color accent;
  final IconData icon;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 32,
      child: Column(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent.withValues(alpha: .16),
              border: Border.all(color: accent.withValues(alpha: .4)),
            ),
            child: Icon(icon, size: 16, color: accent),
          ),
          if (!isLast)
            Expanded(
              child: Container(
                width: 2,
                margin: const EdgeInsets.symmetric(vertical: AppSpacing.s1),
                color: context.appColors.border,
              ),
            ),
        ],
      ),
    );
  }
}

class _StatusChangeChip extends StatelessWidget {
  const _StatusChangeChip({required this.status});

  final PqrsStatus status;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: status.color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s2,
          vertical: AppSpacing.s1,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.flag_outlined, size: 14, color: status.color),
            const SizedBox(width: AppSpacing.s1),
            Text(
              'Pasó a ${status.label}',
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: status.color),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shared date formatting so the three profiles show identical timestamps.
String formatPqrsDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

String formatPqrsDateTime(DateTime date) =>
    '${formatPqrsDate(date)} · ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
