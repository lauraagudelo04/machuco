import 'package:flutter/material.dart';
import 'package:machuco/controllers/auth/admin_access_controller.dart';
import 'package:machuco/core/design_system/design_system.dart';
import 'package:machuco/service/auth/auth_service.dart';

/// Tarjeta "Sesión activa" del login: cerrar sesión, eliminar cuenta y, para
/// administradores, el acceso a las solicitudes de propietarios.
///
/// Ocultar un acceso aquí es solo UX; la autorización real está en
/// `firestore.rules`.
class ActiveSessionCard extends StatelessWidget {
  const ActiveSessionCard({
    super.key,
    required this.session,
    required this.onLogout,
    required this.onDeleteAccount,
    this.adminController,
    this.onOpenOwnerApprovals,
  });

  final AuthSession session;
  final VoidCallback onLogout;
  final VoidCallback onDeleteAccount;
  final AdminAccessController? adminController;
  final VoidCallback? onOpenOwnerApprovals;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controller = adminController;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sesión activa',
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.s1),
          Text(session.name, style: theme.textTheme.bodyMedium),
          const SizedBox(height: AppSpacing.s1),
          Text(
            session.email,
            style: theme.textTheme.bodySmall?.copyWith(
              color: context.appColors.textSecondary,
            ),
          ),
          if (controller != null && onOpenOwnerApprovals != null) ...[
            const SizedBox(height: AppSpacing.s3),
            ListenableBuilder(
              listenable: controller,
              builder: (context, _) {
                final count = controller.pendingCount;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  minVerticalPadding: AppSpacing.s2,
                  leading: const Icon(Icons.how_to_reg_outlined),
                  title: const Text('Solicitudes de propietarios'),
                  subtitle: Text(
                    count == 1 ? '1 pendiente' : '$count pendientes',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: onOpenOwnerApprovals,
                );
              },
            ),
          ],
          const SizedBox(height: AppSpacing.s3),
          AppButton(
            label: 'Cerrar sesión',
            variant: AppButtonVariant.secondary,
            onPressed: onLogout,
          ),
          const SizedBox(height: AppSpacing.s2),
          AppButton(
            label: 'Eliminar cuenta',
            icon: Icons.delete_outline,
            variant: AppButtonVariant.destructive,
            size: AppButtonSize.medium,
            onPressed: onDeleteAccount,
          ),
        ],
      ),
    );
  }
}
