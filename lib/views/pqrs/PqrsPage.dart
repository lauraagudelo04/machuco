import 'package:flutter/material.dart';

import '../../core/design_system/components/app_button.dart';
import '../../core/design_system/components/app_card.dart';
import '../../core/design_system/theme/app_theme_extensions.dart';
import '../../core/design_system/tokens/app_spacing.dart';
import 'client_view/pqrs_page.dart';
import 'data/pqrs_store.dart';
import 'models/pqrs_models.dart';
import 'owner_view/pqrs_page.dart';
import 'system_admin_view/pqrs_page.dart';
import 'widgets/pqrs_profile_picker.dart';
import 'widgets/pqrs_stats_panel.dart';

/// Entry point of the PQRS module.
///
/// It summarises the flow shared by the three profiles and opens the modal that
/// routes to each profile view. Navigation is done with [Navigator.push] on
/// purpose: the app router is still being built by the team, so `main.dart`
/// stays untouched.
class PqrsPage extends StatelessWidget {
  const PqrsPage({super.key, this.store});

  final PqrsStore? store;

  PqrsStore get _store => store ?? PqrsStore.instance;

  Future<void> _openProfilePicker(BuildContext context) async {
    final actor = await showPqrsProfilePicker(context);
    if (actor == null || !context.mounted) return;

    final page = switch (actor) {
      PqrsActor.client => ClientPqrsPage(store: _store),
      PqrsActor.owner => OwnerPqrsPage(store: _store),
      PqrsActor.systemAdmin => SystemAdminPqrsPage(store: _store),
    };

    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => page),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('PQRS')),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _store,
          builder: (context, _) {
            final stats = PqrsStats.from(_store.all);

            return ListView(
              padding: const EdgeInsets.all(AppSpacing.screen),
              children: [
                Text(
                  'Peticiones, quejas, reclamos y sugerencias',
                  style: theme.textTheme.headlineMedium,
                ),
                const SizedBox(height: AppSpacing.s2),
                Text(
                  'Una misma solicitud recorre tres perfiles: el cliente la radica, '
                  'el propietario la atiende y el cliente la cierra. El administrador '
                  'del sistema supervisa el comportamiento.',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: context.appColors.textSecondary),
                ),
                const SizedBox(height: AppSpacing.s5),
                const _FlowCard(),
                const SizedBox(height: AppSpacing.s5),
                AppButton(
                  label: 'Ir a una vista de PQRS',
                  icon: Icons.switch_account_outlined,
                  onPressed: () => _openProfilePicker(context),
                ),
                const SizedBox(height: AppSpacing.s6),
                PqrsStatsPanel(
                  stats: stats,
                  title: 'Panorama general',
                  subtitle: 'Datos simulados de todos los moteles del sistema.',
                  highlightLabel: 'Atendidas',
                  highlightRate: stats.attentionRate,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _FlowCard extends StatelessWidget {
  const _FlowCard();

  static const _steps = <({PqrsActor actor, String title, String detail})>[
    (
      actor: PqrsActor.client,
      title: 'El cliente radica',
      detail: 'Describe lo que encontró y adjunta fotos como evidencia.',
    ),
    (
      actor: PqrsActor.owner,
      title: 'El propietario atiende',
      detail: 'Responde, sube fotos del avance y marca la solución.',
    ),
    (
      actor: PqrsActor.client,
      title: 'El cliente cierra',
      detail: 'Confirma que la solución cubre lo solicitado y cierra la PQRS.',
    ),
    (
      actor: PqrsActor.systemAdmin,
      title: 'El administrador supervisa',
      detail: 'Consulta detalle, estado y porcentajes por motel, sin intervenir.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Cómo funciona el flujo', style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.s4),
          for (var index = 0; index < _steps.length; index++) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _steps[index].actor.color.withValues(alpha: .16),
                  ),
                  child: Text(
                    '${index + 1}',
                    style: theme.textTheme.labelLarge
                        ?.copyWith(color: _steps[index].actor.color),
                  ),
                ),
                const SizedBox(width: AppSpacing.s3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _steps[index].title,
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _steps[index].detail,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: context.appColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (index != _steps.length - 1)
              const SizedBox(height: AppSpacing.s4),
          ],
        ],
      ),
    );
  }
}
