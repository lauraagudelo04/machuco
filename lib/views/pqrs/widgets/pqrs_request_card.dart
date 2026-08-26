import 'package:flutter/material.dart';

import '../../../core/design_system/components/app_card.dart';
import '../../../core/design_system/theme/app_theme_extensions.dart';
import '../../../core/design_system/tokens/app_spacing.dart';
import '../models/pqrs_models.dart';
import 'pqrs_status_badge.dart';
import 'pqrs_timeline.dart';

/// Summary card of a PQRS request, reused by the three profiles.
///
/// [showClient] is meant for the owner and administrator, who need to know who
/// filed the request; the client already knows.
class PqrsRequestCard extends StatelessWidget {
  const PqrsRequestCard({
    super.key,
    required this.request,
    this.onTap,
    this.showClient = false,
    this.showMotel = false,
    this.trailingHint,
  });

  final PqrsRequest request;
  final VoidCallback? onTap;
  final bool showClient;
  final bool showMotel;
  final String? trailingHint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final photos = request.allAttachments.length;

    final meta = <String>[
      request.type.label,
      formatPqrsDate(request.createdAt),
      if (showMotel) request.motelName,
      if (showClient) request.clientName,
    ];

    return AppCard(
      onTap: onTap,
      semanticLabel: '${request.subject}, ${request.status.label}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(request.type.icon, color: theme.colorScheme.primary),
              const SizedBox(width: AppSpacing.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.subject,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      meta.join(' · '),
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: context.appColors.textSecondary),
                    ),
                  ],
                ),
              ),
              if (onTap != null)
                Icon(
                  Icons.chevron_right,
                  color: context.appColors.textSecondary,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.s3),
          Text(
            request.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: context.appColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.s3),
          Wrap(
            spacing: AppSpacing.s2,
            runSpacing: AppSpacing.s2,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              PqrsStatusBadge(status: request.status),
              _MetaChip(
                icon: Icons.forum_outlined,
                label: '${request.trace.length}',
                tooltip: 'Movimientos de trazabilidad',
              ),
              if (photos > 0)
                _MetaChip(
                  icon: Icons.photo_library_outlined,
                  label: '$photos',
                  tooltip: 'Fotos adjuntas',
                ),
              if (trailingHint != null)
                Text(
                  trailingHint!,
                  style: theme.textTheme.labelMedium
                      ?.copyWith(color: theme.colorScheme.primary),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label, required this.tooltip});

  final IconData icon;
  final String label;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Semantics(
        label: '$tooltip: $label',
        child: ExcludeSemantics(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: context.appColors.textSecondary),
              const SizedBox(width: AppSpacing.s1),
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: context.appColors.textSecondary,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
