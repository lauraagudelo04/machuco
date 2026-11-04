import 'package:flutter/material.dart';
import 'client_view/client_notification_view.dart';
import 'system_admin_view/system_admin_notification_view.dart';

export '../../controllers/notification/notification_controller.dart';
export '../../models/notification/notification_model.dart';
export 'client_view/client_notification_view.dart';
export 'system_admin_view/system_admin_notification_view.dart';

/// NotificationPage sirve como contenedor principal para cambiar
/// entre la vista de Cliente y Administrador del Sistema.
class NotificationPage extends StatelessWidget {
  const NotificationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        body: const TabBarView(
          children: [
            ClientNotificationView(),
            SystemAdminNotificationView(),
          ],
        ),
        bottomNavigationBar: Material(
          color: Theme.of(context).cardColor,
          elevation: 8,
          child: const TabBar(
            tabs: [
              Tab(
                icon: Icon(Icons.person),
                text: 'Cliente',
              ),
              Tab(
                icon: Icon(Icons.admin_panel_settings),
                text: 'System Admin',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
