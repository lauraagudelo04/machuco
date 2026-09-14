import 'package:flutter/material.dart';

import 'package:machuco/core/design_system/theme/app_theme_extensions.dart';
import 'package:machuco/core/design_system/tokens/app_colors.dart';
import 'package:machuco/core/design_system/tokens/app_radius.dart';
import 'package:machuco/core/design_system/tokens/app_spacing.dart';

/// Una opción seleccionable dentro de un grupo de filtro (por ejemplo, un
/// motel específico o un estado de reserva). El valor siempre se modela
/// como `String` para que el widget se mantenga genérico; quien lo use
/// (Propietario, y más adelante Administrador) decide cómo mapear ese
/// `String` a su propio dominio (id de motel, `ReservationStatus`, etc.).
class ReservationFilterOption {
  const ReservationFilterOption({required this.value, required this.label});

  final String value;
  final String label;
}

/// Un grupo de filtro (p. ej. "Motel", "Estado", "Habitación") mostrado
/// como un chip individual dentro de [ReservationFilterBar]. Al tocarlo se
/// despliega un menú con [options] más una opción para volver a "todos".
class ReservationFilterGroup {
  const ReservationFilterGroup({
    required this.label,
    required this.options,
    required this.selectedValue,
    required this.onChanged,
    this.allLabel = 'Todos',
  });

  final String label;
  final List<ReservationFilterOption> options;
  final String? selectedValue;
  final ValueChanged<String?> onChanged;
  final String allLabel;

  String get selectedLabel {
    final value = selectedValue;
    if (value == null) return allLabel;
    for (final option in options) {
      if (option.value == value) return option.label;
    }
    return value;
  }
}

/// Fila horizontal desplazable de chips de filtro, cada uno representando
/// un [ReservationFilterGroup]. Es puramente de presentación: no contiene
/// lógica de negocio propia, solo emite los cambios de selección mediante
/// los callbacks de cada grupo. Pensado para ser reutilizado por
/// Propietario y Administrador en sus respectivas vistas de reservas.
class ReservationFilterBar extends StatelessWidget {
  const ReservationFilterBar({super.key, required this.groups});

  final List<ReservationFilterGroup> groups;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: groups.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.s2),
        itemBuilder: (context, index) =>
            _ReservationFilterChip(group: groups[index]),
      ),
    );
  }
}

class _ReservationFilterChip extends StatelessWidget {
  const _ReservationFilterChip({required this.group});

  final ReservationFilterGroup group;

  @override
  Widget build(BuildContext context) {
    final isActive = group.selectedValue != null;
    final activeColor = AppColors.violet;
    return PopupMenuButton<String?>(
      tooltip: group.label,
      onSelected: group.onChanged,
      itemBuilder: (context) => [
        PopupMenuItem<String?>(value: null, child: Text(group.allLabel)),
        for (final option in group.options)
          PopupMenuItem<String?>(
            value: option.value,
            child: Text(option.label),
          ),
      ],
      child: Semantics(
        button: true,
        label: '${group.label}: ${group.selectedLabel}',
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s3),
          decoration: BoxDecoration(
            color: isActive
                ? activeColor.withValues(alpha: .14)
                : context.appColors.elevated,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(
              color: isActive ? activeColor : context.appColors.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  '${group.label}: ${group.selectedLabel}',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: isActive ? activeColor : null,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.s1),
              Icon(
                Icons.arrow_drop_down,
                color: isActive ? activeColor : context.appColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
