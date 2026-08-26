import 'package:flutter/material.dart';

import '../../../core/design_system/tokens/app_radius.dart';
import '../../../core/design_system/tokens/app_spacing.dart';
import '../models/pqrs_models.dart';

/// Pill showing the status of a PQRS request.
class PqrsStatusBadge extends StatelessWidget {
  const PqrsStatusBadge({super.key, required this.status, this.compact = false});

  final PqrsStatus status;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Estado: ${status.label}',
      child: ExcludeSemantics(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: status.color.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(color: status.color.withValues(alpha: .28)),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? AppSpacing.s2 : AppSpacing.s3,
              vertical: AppSpacing.s1,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(status.icon, size: compact ? 14 : 16, color: status.color),
                const SizedBox(width: AppSpacing.s1),
                Text(
                  status.label,
                  style: (compact
                          ? Theme.of(context).textTheme.labelSmall
                          : Theme.of(context).textTheme.labelMedium)
                      ?.copyWith(color: status.color),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
