import 'package:flutter/material.dart';
import '../../core/design_system/components/app_card.dart';
import '../../core/design_system/theme/app_theme_extensions.dart';
import '../../core/design_system/tokens/app_colors.dart';
import '../../core/design_system/tokens/app_radius.dart';
import '../../core/design_system/tokens/app_spacing.dart';
import '../../models/notification/notification_model.dart';

class AdminNotificationCard extends StatelessWidget {
  const AdminNotificationCard({
    super.key,
    required this.notification,
  });

  final AppNotification notification;

  @override
  Widget build(BuildContext context) {
    final color = notification.type.color;
    final isAll = notification.target == NotificationTarget.all;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s2,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .15),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(notification.type.icon, size: 14, color: color),
                    const SizedBox(width: 4),
                    Text(
                      notification.type.label,
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(color: color, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.s2),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s2,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: isAll
                      ? AppColors.violet.withValues(alpha: .15)
                      : AppColors.fuchsia.withValues(alpha: .15),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Text(
                  isAll
                      ? '📢 Todos'
                      : '👤 Para: ${notification.recipientUser ?? "Usuario"}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: isAll ? AppColors.violet : AppColors.fuchsia,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              const Spacer(),
              Text(
                notification.time,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: context.appColors.textMuted,
                    ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s3),
          Text(
            notification.title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            notification.message,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: context.appColors.textSecondary,
                ),
          ),
        ],
      ),
    );
  }
}
