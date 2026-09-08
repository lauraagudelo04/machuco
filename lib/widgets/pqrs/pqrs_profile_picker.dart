import 'package:flutter/material.dart';
import 'package:machuco/core/design_system/design_system.dart';
import 'package:machuco/models/pqrs/pqrs.dart';
import 'package:machuco/widgets/pqrs/pqrs_presentation.dart';

/// Opens the modal that asks which PQRS view to navigate to.
///
/// It returns the chosen profile, or `null` when the user dismisses it. The
/// caller performs the navigation, which keeps the modal free of route
/// knowledge and testable on its own.
Future<PqrsActor?> showPqrsProfilePicker(BuildContext context) {
  return showModalBottomSheet<PqrsActor>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => const _PqrsProfilePicker(),
  );
}

class _PqrsProfilePicker extends StatelessWidget {
  const _PqrsProfilePicker();

  static const _options = <({PqrsActor actor, String title, String description})>[
    (
      actor: PqrsActor.client,
      title: 'Cliente',
      description:
          'Radica solicitudes, adjunta fotos de lo que encontró y cierra la PQRS cuando la solución lo satisface.',
    ),
    (
      actor: PqrsActor.owner,
      title: 'Propietario',
      description:
          'Atiende las PQRS de su motel, registra avances con fotos y consulta sus indicadores de atención.',
    ),
    (
      actor: PqrsActor.systemAdmin,
      title: 'Administrador del sistema',
      description:
          'Consulta en solo lectura las PQRS de un motel y su comportamiento estadístico.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screen,
          0,
          AppSpacing.screen,
          AppSpacing.screen,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('¿A qué vista de PQRS quieres ir?', style: theme.textTheme.headlineSmall),
            const SizedBox(height: AppSpacing.s2),
            Text(
              'Cada perfil ve la misma solicitud con permisos distintos.',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: context.appColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.s5),
            for (final option in _options)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.s3),
                child: _ProfileOption(
                  actor: option.actor,
                  title: option.title,
                  description: option.description,
                  onTap: () => Navigator.of(context).pop(option.actor),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ProfileOption extends StatelessWidget {
  const _ProfileOption({
    required this.actor,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final PqrsActor actor;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      button: true,
      label: 'Ir a la vista de $title',
      child: ExcludeSemantics(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: context.appColors.border),
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.s4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: actor.color.withValues(alpha: .16),
                      ),
                      child: Icon(actor.icon, color: actor.color),
                    ),
                    const SizedBox(width: AppSpacing.s4),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: theme.textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: AppSpacing.s1),
                          Text(
                            description,
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: context.appColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s2),
                    Icon(Icons.arrow_forward, color: context.appColors.textSecondary),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
