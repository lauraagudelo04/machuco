import 'package:flutter/material.dart';
import 'package:machuco/core/design_system/design_system.dart';
import 'package:machuco/routes/routes.dart';

class BookingHomePage extends StatelessWidget {
  const BookingHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    const profiles = [
      _ProfileData(
        'Cliente',
        'Crear, consultar, pagar y cancelar reservas.',
        Icons.person_outline,
        AppRoutes.clientBookings,
      ),
      _ProfileData(
        'Propietario',
        'Revisar reservas por hotel, cancelar y notificar.',
        Icons.storefront_outlined,
        AppRoutes.ownerBookings,
      ),
      _ProfileData(
        'Administrador',
        'Administrar los propietarios de moteles y su estado.',
        Icons.admin_panel_settings_outlined,
        AppRoutes.ownerManagement,
      ),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('MACHUCO · Reservas')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 920),
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.screen),
              children: [
                Text(
                  'Demostración por perfil',
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                const SizedBox(height: AppSpacing.s2),
                Text(
                  'Selecciona un rol para recorrer las vistas visuales del módulo booking.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: context.appColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.s6),
                ...profiles.map(
                  (profile) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.s3),
                    child: AppCard(
                      onTap: () => Navigator.pushNamed(context, profile.route),
                      semanticLabel: 'Abrir perfil ${profile.title}',
                      child: Row(
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: context.appColors.elevated,
                              borderRadius: BorderRadius.circular(AppRadius.lg),
                            ),
                            child: Icon(
                              profile.icon,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.s4),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  profile.title,
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                const SizedBox(height: AppSpacing.s1),
                                Text(
                                  profile.description,
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: context.appColors.textSecondary,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios, size: 18),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.s4),
                AppCard(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: AppSpacing.s3),
                      Expanded(
                        child: Text(
                          'Este acceso es temporal. No autentica roles ni persiste cambios; solo permite validar navegación y apariencia.',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: context.appColors.textSecondary,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileData {
  const _ProfileData(this.title, this.description, this.icon, this.route);
  final String title;
  final String description;
  final IconData icon;
  final String route;
}
