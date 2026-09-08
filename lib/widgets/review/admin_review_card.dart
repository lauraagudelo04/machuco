import 'package:flutter/material.dart';
import 'package:machuco/controllers/review/review_administration_controller.dart';
import 'package:machuco/core/design_system/design_system.dart';

/// Tarjeta de una reseña dentro del panel de administración.
/// Solo pinta lo que recibe; toda decisión (ocultar, eliminar, etc.) se
/// delega hacia arriba mediante callbacks.
class AdminReviewCard extends StatelessWidget {
  const AdminReviewCard({
    super.key,
    required this.entry,
    required this.onToggleVisibility,
    required this.onDismissReport,
    required this.onReply,
    required this.onDelete,
  });

  final AdminReviewEntry entry;
  final VoidCallback onToggleVisibility;
  final VoidCallback onDismissReport;
  final VoidCallback onReply;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final review = entry.review;
    final isReported = entry.status == ReviewModerationStatus.reported;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _AuthorAvatar(
                initial: review.author.isNotEmpty ? review.author[0] : '?',
              ),
              const SizedBox(width: AppSpacing.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.author,
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${review.title} · ${_formatDate(review.date)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.appColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              _StarRow(rating: review.rating),
              PopupMenuButton<String>(
                tooltip: 'Acciones',
                onSelected: (value) {
                  switch (value) {
                    case 'toggle':
                      onToggleVisibility();
                    case 'dismiss':
                      onDismissReport();
                    case 'reply':
                      onReply();
                    case 'delete':
                      onDelete();
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'toggle',
                    child: ListTile(
                      leading: Icon(
                        entry.status == ReviewModerationStatus.hidden
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      title: Text(
                        entry.status == ReviewModerationStatus.hidden
                            ? 'Mostrar'
                            : 'Ocultar',
                      ),
                    ),
                  ),
                  if (isReported)
                    const PopupMenuItem(
                      value: 'dismiss',
                      child: ListTile(
                        leading: Icon(Icons.task_alt_outlined),
                        title: Text('Descartar reporte'),
                      ),
                    ),
                  const PopupMenuItem(
                    value: 'reply',
                    child: ListTile(
                      leading: Icon(Icons.reply_outlined),
                      title: Text('Responder'),
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      leading: Icon(Icons.delete_outline),
                      title: Text('Eliminar'),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s3),
          Text(
            review.body,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: context.appColors.textSecondary),
          ),
          if (isReported && entry.reportReason != null) ...[
            const SizedBox(height: AppSpacing.s3),
            _InlineNote(
              icon: Icons.flag_outlined,
              color: AppColors.maintenance,
              label: 'Motivo del reporte',
              text: entry.reportReason!,
            ),
          ],
          if (entry.adminReply != null) ...[
            const SizedBox(height: AppSpacing.s3),
            _InlineNote(
              icon: Icons.support_agent_outlined,
              color: AppColors.violet,
              label: 'Respuesta del administrador',
              text: entry.adminReply!,
            ),
          ],
          const SizedBox(height: AppSpacing.s3),
          _StatusChip(status: entry.status),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final ReviewModerationStatus status;

  Color _colorFor(ReviewModerationStatus s) => switch (s) {
    ReviewModerationStatus.visible => AppColors.available,
    ReviewModerationStatus.hidden => AppColors.blocked,
    ReviewModerationStatus.reported => AppColors.maintenance,
  };

  IconData _iconFor(ReviewModerationStatus s) => switch (s) {
    ReviewModerationStatus.visible => Icons.visibility_outlined,
    ReviewModerationStatus.hidden => Icons.visibility_off_outlined,
    ReviewModerationStatus.reported => Icons.flag_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final color = _colorFor(status);
    return Semantics(
      label: 'Estado: ${status.label}',
      child: ExcludeSemantics(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: color.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s3,
              vertical: AppSpacing.s1,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_iconFor(status), size: 16, color: color),
                const SizedBox(width: AppSpacing.s1),
                Text(
                  status.label,
                  style: Theme.of(
                    context,
                  ).textTheme.labelMedium?.copyWith(color: color),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InlineNote extends StatelessWidget {
  const _InlineNote({
    required this.icon,
    required this.color,
    required this.label,
    required this.text,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: color.withValues(alpha: .24)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: AppSpacing.s2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    text,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: context.appColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StarRow extends StatelessWidget {
  const _StarRow({required this.rating});

  final int rating;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        5,
        (i) => Icon(
          i < rating ? Icons.star_rounded : Icons.star_outline_rounded,
          size: 16,
          color: i < rating
              ? const Color(0xFFFFB300)
              : context.appColors.textMuted,
        ),
      ),
    );
  }
}

class _AuthorAvatar extends StatelessWidget {
  const _AuthorAvatar({required this.initial});

  final String initial;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        gradient: AppGradients.primary,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      alignment: Alignment.center,
      child: Text(
        initial.toUpperCase(),
        style: Theme.of(
          context,
        ).textTheme.labelLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
      ),
    );
  }
}

String _formatDate(DateTime date) => '${date.day}/${date.month}/${date.year}';