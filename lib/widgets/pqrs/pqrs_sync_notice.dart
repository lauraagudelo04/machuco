import 'package:flutter/material.dart';
import 'package:machuco/core/design_system/design_system.dart';
import 'package:machuco/database/repository/pqrs/pqrs_repository.dart';

/// Short label for a request that is not synchronized yet. Draws nothing for a
/// synchronized one. The state is always icon plus text, never color alone.
class PqrsSyncBadge extends StatelessWidget {
  const PqrsSyncBadge({super.key, required this.sync});

  final PqrsSyncState sync;

  @override
  Widget build(BuildContext context) {
    if (sync.isSynced) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final failed = sync.isFailed;
    final color = failed ? theme.colorScheme.error : theme.colorScheme.primary;
    final label = failed ? 'No se pudo enviar' : 'Pendiente de envío';

    return Semantics(
      label: label,
      child: ExcludeSemantics(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: color.withValues(alpha: AppOpacity.softFill),
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
                Icon(
                  failed ? Icons.error_outline : Icons.cloud_upload_outlined,
                  size: 16,
                  color: color,
                ),
                const SizedBox(width: AppSpacing.s1),
                Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(color: color),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Banner of the detail for a pending or failed request. A failed one shows
/// the reason and the "Reintentar" and "Descartar" actions.
class PqrsSyncNotice extends StatelessWidget {
  const PqrsSyncNotice({
    super.key,
    required this.sync,
    required this.onRetry,
    required this.onDiscard,
    this.busy = false,
  });

  final PqrsSyncState sync;
  final VoidCallback onRetry;
  final VoidCallback onDiscard;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    if (sync.isSynced) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final failed = sync.isFailed;

    return Semantics(
      liveRegion: true,
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.s3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PqrsSyncBadge(sync: sync),
            const SizedBox(height: AppSpacing.s2),
            Text(
              failed
                  ? (sync.reason ?? 'El servidor no aceptó la acción.')
                  : 'Se enviará cuando haya conexión.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.s3),
            Wrap(
              spacing: AppSpacing.s2,
              runSpacing: AppSpacing.s2,
              children: [
                AppButton(
                  label: 'Reintentar',
                  icon: Icons.refresh,
                  size: AppButtonSize.medium,
                  expanded: false,
                  variant: AppButtonVariant.secondary,
                  loading: busy,
                  onPressed: onRetry,
                ),
                if (failed)
                  AppButton(
                    label: 'Descartar',
                    icon: Icons.delete_outline,
                    size: AppButtonSize.medium,
                    expanded: false,
                    variant: AppButtonVariant.destructive,
                    onPressed: busy ? null : onDiscard,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
