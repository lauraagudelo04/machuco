import 'package:flutter/material.dart';
import '../../../controllers/notification/notification_controller.dart';
import '../../../core/design_system/components/app_card.dart';
import '../../../core/design_system/theme/app_theme_extensions.dart';
import '../../../core/design_system/tokens/app_colors.dart';
import '../../../core/design_system/tokens/app_radius.dart';
import '../../../core/design_system/tokens/app_spacing.dart';
import '../../../routes/routes.dart';
import '../../../widgets/notification/admin_notification_card.dart';
import '../../../widgets/notification/create_notification_sheet.dart';

class SystemAdminNotificationView extends StatefulWidget {
  const SystemAdminNotificationView({super.key});

  @override
  State<SystemAdminNotificationView> createState() =>
      _SystemAdminNotificationViewState();
}

class _SystemAdminNotificationViewState
    extends State<SystemAdminNotificationView> {
  final NotificationController _controller = NotificationController();

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

  void _openCreateNotificationDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const CreateNotificationSheet(),
    );
  }

  void _goBackToAdminHome() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushNamedAndRemoveUntil(
        AppRoutes.adminMotels,
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final notifications = _controller.notifications;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificaciones Admin'),
        actions: [
          IconButton(
            icon: const Icon(Icons.home_outlined),
            tooltip: 'Volver al Inicio (Admin)',
            onPressed: _goBackToAdminHome,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.screen),
              child: AppCard(
                padding: const EdgeInsets.all(AppSpacing.s4),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.violet.withValues(alpha: .15),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: const Icon(
                        Icons.campaign,
                        color: AppColors.violet,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s3),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Panel de Emisión (System Admin)',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Toca el botón flotante abajo a la derecha para enviar un anuncio o alerta masiva/individual.',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: context.appColors.textSecondary,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screen,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Historial de Notificaciones Emitidas',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: context.appColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  Chip(
                    label: Text('${notifications.length} enviadas'),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.s2),
            Expanded(
              child: notifications.isEmpty
                  ? const Center(
                      child: Text('No hay notificaciones enviadas aún.'),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.screen,
                        0,
                        AppSpacing.screen,
                        AppSpacing.screen,
                      ),
                      itemCount: notifications.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: AppSpacing.s3),
                      itemBuilder: (context, index) {
                        final notification = notifications[index];
                        return AdminNotificationCard(
                          notification: notification,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openCreateNotificationDialog(context),
        icon: const Icon(Icons.notifications_active),
        label: const Text('Nueva Notificación'),
        backgroundColor: AppColors.violet,
        foregroundColor: Colors.white,
      ),
    );
  }
}
