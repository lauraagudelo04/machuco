import 'package:flutter/material.dart';
import 'package:machuco/controllers/review/owner_review_controller.dart';
import 'package:machuco/core/design_system/design_system.dart';

class OwnerReviewCard extends StatelessWidget {
  const OwnerReviewCard({
    super.key,
    required this.entry,
    required this.onReply,
  });

  final OwnerReviewEntry entry;
  final VoidCallback onReply;

  @override
  Widget build(BuildContext context) {
    final review = entry.review;
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
                      '${entry.motelName} · ${_formatDate(review.date)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.appColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              _StarRow(rating: review.rating),
            ],
          ),
          const SizedBox(height: AppSpacing.s3),
          Text(
            review.title,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.s1),
          Text(
            review.body,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: context.appColors.textSecondary),
          ),
          if (entry.ownerReply != null) ...[
            const SizedBox(height: AppSpacing.s3),
            _InlineNote(
              icon: Icons.storefront_outlined,
              color: AppColors.violet,
              label: 'Tu respuesta',
              text: entry.ownerReply!,
            ),
          ],
          const SizedBox(height: AppSpacing.s3),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onReply,
              icon: const Icon(Icons.reply_outlined, size: 18),
              label: Text(
                entry.ownerReply == null ? 'Responder' : 'Editar respuesta',
              ),
            ),
          ),
        ],
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
