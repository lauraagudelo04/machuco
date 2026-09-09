import 'package:flutter/material.dart';
import '../../../controllers/notification/notification_controller.dart';
import '../../../core/design_system/components/app_feedback.dart';
import '../../../core/design_system/theme/app_theme_extensions.dart';
import '../../../core/design_system/tokens/app_colors.dart';
import '../../../core/design_system/tokens/app_radius.dart';
import '../../../core/design_system/tokens/app_spacing.dart';
import '../../../models/notification/notification_model.dart';
import '../../../widgets/notification/owner_notification_card.dart';

/// La Vista (owner_notification_view.dart)
/// Vista de notificaciones para Propietarios de Moteles (recibe alertas de reservas, pagos, reseñas y avisos del sistema).
class OwnerNotificationView extends StatefulWidget {
  const OwnerNotificationView({super.key});

  @override
  State<OwnerNotificationView> createState() => _OwnerNotificationViewState();
}

class _OwnerNotificationViewState extends State<OwnerNotificationView> {
  final NotificationController _controller = NotificationController();
  NotificationType? _filter;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final visibleNotifications = _controller.getFilteredNotifications(_filter);
    final unreadCount = _controller.unreadCount;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificaciones Propietario'),
        actions: [
          if (unreadCount > 0)
            IconButton(
              tooltip: 'Marcar todas como leídas',
              onPressed: () => _controller.markAllRead(),
              icon: const Icon(Icons.done_all),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screen,
                AppSpacing.s4,
                AppSpacing.screen,
                0,
              ),
              child: _buildHeader(context, unreadCount),
            ),
            const SizedBox(height: AppSpacing.s4),
            _buildFilters(context),
            const SizedBox(height: AppSpacing.s4),
            Expanded(
              child: visibleNotifications.isEmpty
                  ? _buildEmptyState()
                  : ListView.separated(
                      padding: const EdgeInsets.all(AppSpacing.screen),
                      itemCount: visibleNotifications.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: AppSpacing.s3),
                      itemBuilder: (context, index) {
                        final notification = visibleNotifications[index];
                        return OwnerNotificationCard(
                          notification: notification,
                          onTap: () => _controller.markAsRead(notification),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, int unreadCount) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Centro de Alertas de tu Motel',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: AppSpacing.s2),
        Row(
          children: [
            Expanded(
              child: Text(
                'Recibe notificaciones de nuevas reservas, pagos recibidos y opiniones de clientes.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: context.appColors.textSecondary,
                    ),
              ),
            ),
            if (unreadCount > 0) ...[
              const SizedBox(width: AppSpacing.s3),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s2,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.fuchsia.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  '$unreadCount pendientes',
                  style: Theme.of(context)
                      .textTheme
                      .labelMedium
                      ?.copyWith(color: AppColors.fuchsia),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildFilters(BuildContext context) {
    final options = <(NotificationType?, String)>[
      (null, 'Todas'),
      for (final type in NotificationType.values) (type, type.label),
    ];
    return SizedBox(
      height: 42,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
        scrollDirection: Axis.horizontal,
        itemCount: options.length,
        separatorBuilder: (context, index) =>
            const SizedBox(width: AppSpacing.s2),
        itemBuilder: (context, index) {
          final (type, label) = options[index];
          return ChoiceChip(
            label: Text(label),
            selected: _filter == type,
            onSelected: (_) => setState(() => _filter = type),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return const AppEmptyState(
      icon: Icons.storefront_outlined,
      title: 'Sin notificaciones para mostrar',
      message: 'Las novedades sobre tus sedes y reservas aparecerán en esta sección.',
    );
  }
}
