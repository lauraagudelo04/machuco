import 'package:flutter/material.dart';

import 'package:machuco/core/design_system/design_system.dart';

/// Menú lateral del panel de administración.
///
/// Muestra el acceso a las solicitudes de propietarios pendientes (con su
/// contador), al perfil del administrador y al cierre de sesión.
class AdminPanelDrawer extends StatelessWidget {
  const AdminPanelDrawer({
    super.key,
    required this.pendingRequests,
    required this.adminEmail,
    required this.onOpenApprovals,
    required this.onOpenAdministrators,
    required this.onOpenNotifications,
    required this.onOpenProfile,
    required this.onLogout,
  });

  final int pendingRequests;
  final String? adminEmail;
  final VoidCallback onOpenApprovals;
  final VoidCallback onOpenAdministrators;
  final VoidCallback onOpenNotifications;
  final VoidCallback onOpenProfile;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final email = adminEmail?.trim();
    final textTheme = Theme.of(context).textTheme;
    final onPrimary = Theme.of(context).colorScheme.onPrimary;
    return Drawer(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'Menú Administrador',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.headlineMedium?.copyWith(color: onPrimary),
                ),
                const SizedBox(height: AppSpacing.s1),
                Text(
                  email == null || email.isEmpty
                      ? 'Sesión de administrador'
                      : 'Sesión: $email',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall?.copyWith(color: onPrimary),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.verified_user_outlined),
            title: const Text('Solicitudes de propietarios'),
            subtitle: Text(
              pendingRequests == 0
                  ? 'Sin solicitudes pendientes'
                  : '$pendingRequests pendientes',
            ),
            trailing: pendingRequests > 0
                ? Chip(
                    label: Text('$pendingRequests'),
                    backgroundColor: Theme.of(context).colorScheme.primary
                        .withValues(alpha: AppOpacity.softFill),
                    visualDensity: VisualDensity.compact,
                  )
                : null,
            onTap: onOpenApprovals,
          ),
          ListTile(
            leading: const Icon(Icons.admin_panel_settings_outlined),
            title: const Text('Administradores'),
            onTap: onOpenAdministrators,
          ),
          ListTile(
            leading: const Icon(Icons.notifications_outlined),
            title: const Text('Notificaciones'),
            onTap: onOpenNotifications,
          ),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('Mi perfil'),
            onTap: onOpenProfile,
          ),
          const Divider(height: AppSpacing.s4),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Cerrar sesión'),
            onTap: onLogout,
          ),
        ],
      ),
    );
  }
}

/// Aviso del listado de propietarios cuando hay cuentas por aprobar.
class PendingOwnerRequestsBanner extends StatelessWidget {
  const PendingOwnerRequestsBanner({
    super.key,
    required this.count,
    required this.onReview,
  });

  final int count;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    final plural = count == 1 ? 'solicitud' : 'solicitudes';
    return AppCard(
      semanticLabel: 'Solicitudes de propietarios pendientes',
      child: Row(
        children: [
          Icon(
            Icons.hourglass_top_outlined,
            color: context.appColors.textSecondary,
          ),
          const SizedBox(width: AppSpacing.s2),
          Expanded(
            child: Text(
              '$count $plural de propietarios pendientes de aprobación.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          TextButton(onPressed: onReview, child: const Text('Revisar')),
        ],
      ),
    );
  }
}
