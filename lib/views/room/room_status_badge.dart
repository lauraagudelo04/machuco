import 'package:flutter/material.dart';
import 'package:machuco/controllers/room/room_controller_support.dart';
import 'package:machuco/core/design_system/tokens/app_colors.dart';
import 'package:machuco/core/design_system/tokens/app_radius.dart';
import 'package:machuco/core/design_system/tokens/app_spacing.dart';

/// Estado administrativo exclusivo para habitaciones.
class RoomStatusBadge extends StatelessWidget {
  const RoomStatusBadge({super.key, required this.isActive});

  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppColors.available : AppColors.blocked;
    final icon = isActive ? Icons.check_circle_outline : Icons.block_outlined;

    return Semantics(
      label: 'Estado: ${roomAdministrativeLabel(isActive)}',
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
                Icon(icon, size: 16, color: color),
                const SizedBox(width: AppSpacing.s1),
                Text(
                  roomAdministrativeLabel(isActive),
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
