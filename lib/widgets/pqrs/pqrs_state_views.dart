import 'package:flutter/material.dart';
import 'package:machuco/core/design_system/design_system.dart';
import 'package:machuco/models/pqrs/pqrs.dart';
import 'package:machuco/widgets/pqrs/pqrs_presentation.dart';

/// Placeholder shown while a list or a detail loads for the first time.
class PqrsLoadingSkeleton extends StatelessWidget {
  const PqrsLoadingSkeleton({super.key, this.rows = 3});

  final int rows;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var index = 0; index < rows; index++) ...[
          const AppSkeleton(height: 112, borderRadius: AppRadius.lg),
          const SizedBox(height: AppSpacing.s3),
        ],
      ],
    );
  }
}

/// Informative banner (icon plus text) for the offline notice and the like.
class PqrsInfoBanner extends StatelessWidget {
  const PqrsInfoBanner({super.key, required this.message, required this.icon});

  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.s3),
        child: Row(
          children: [
            Icon(icon, color: context.appColors.textSecondary),
            const SizedBox(width: AppSpacing.s3),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Recoverable error shown above content that is already on screen.
class PqrsErrorBanner extends StatelessWidget {
  const PqrsErrorBanner({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.error.withValues(alpha: AppOpacity.softFill),
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s3),
          child: Row(
            children: [
              Icon(Icons.error_outline, color: theme.colorScheme.error),
              const SizedBox(width: AppSpacing.s3),
              Expanded(child: Text(message, style: theme.textTheme.bodySmall)),
              if (onRetry != null)
                TextButton(
                  style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                  onPressed: onRetry,
                  child: const Text('Reintentar'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Notice of a closed or rejected request: no text box and no buttons follow.
class PqrsFinalNotice extends StatelessWidget {
  const PqrsFinalNotice({super.key, required this.status, this.detail});

  final PqrsStatus status;

  /// Optional extra line, e.g. who closed it.
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      liveRegion: true,
      child: AppCard(
        child: Row(
          children: [
            Icon(status.icon, color: status.color),
            const SizedBox(width: AppSpacing.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    status == PqrsStatus.closed
                        ? 'Esta solicitud está cerrada'
                        : 'Esta solicitud está rechazada',
                    style: theme.textTheme.titleSmall,
                  ),
                  if (detail != null)
                    Text(detail!, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
