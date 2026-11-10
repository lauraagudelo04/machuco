import 'package:flutter/material.dart';

import 'package:machuco/core/design_system/tokens/app_colors.dart';
import 'package:machuco/core/design_system/tokens/app_radius.dart';
import 'package:machuco/core/design_system/tokens/app_spacing.dart';
import 'package:machuco/models/auth/account_status.dart';

/// Distintivo del estado de una cuenta (`users/{uid}.accountStatus`).
///
/// No usa `StatusBadge` porque ese componente describe estados de habitaciones
/// y reservas, no de personas.
class AccountStatusChip extends StatelessWidget {
  const AccountStatusChip({super.key, required this.isActive, this.status});

  final bool isActive;

  /// Estado de la cuenta; permite distinguir una cuenta pendiente de
  /// aprobación de una deshabilitada.
  final AccountStatus? status;

  @override
  Widget build(BuildContext context) {
    final pending = status == AccountStatus.pendingApproval;
    final color = pending
        ? AppColors.maintenance
        : (isActive ? AppColors.available : AppColors.blocked);
    final label = pending ? 'Pendiente' : (isActive ? 'Activo' : 'Inactivo');
    return Semantics(
      label: 'Estado: $label',
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
                Icon(
                  pending
                      ? Icons.hourglass_top_outlined
                      : (isActive
                            ? Icons.check_circle_outline
                            : Icons.block_outlined),
                  size: 16,
                  color: color,
                ),
                const SizedBox(width: AppSpacing.s1),
                Text(
                  label,
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
