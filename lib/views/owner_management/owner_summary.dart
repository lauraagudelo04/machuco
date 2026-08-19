import 'package:flutter/material.dart';

import 'package:machuco/core/design_system/components/app_card.dart';
import 'package:machuco/core/design_system/theme/app_theme_extensions.dart';
import 'package:machuco/core/design_system/tokens/app_colors.dart';
import 'package:machuco/core/design_system/tokens/app_radius.dart';
import 'package:machuco/core/design_system/tokens/app_spacing.dart';

import 'owner_models.dart';

/// Resumen de solo lectura con los datos de un propietario.
///
/// Lo comparten la confirmación de creación y el detalle, para que el usuario
/// vea siempre la misma información con el mismo orden.
class OwnerSummary extends StatelessWidget {
  const OwnerSummary({super.key, required this.owner});

  final OwnerFormData owner;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SummaryRow(label: 'Nombre completo', value: owner.fullName),
          _SummaryRow(
            label: owner.documentType.description,
            value: owner.documentLabel,
          ),
          _SummaryRow(label: 'Correo electrónico', value: owner.email),
          _SummaryRow(label: 'Teléfono', value: owner.phone),
          _SummaryRow(label: 'Dirección', value: owner.address),
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.s3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Estado',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: context.appColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.s2),
                OwnerStatusChip(isActive: owner.isActive),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final hasValue = value != null && value!.trim().isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: textTheme.labelMedium?.copyWith(
              color: context.appColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.s1),
          Text(
            hasValue ? value! : 'Sin registrar',
            style: textTheme.bodyLarge?.copyWith(
              color: hasValue ? null : context.appColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

/// Distintivo de estado de un propietario.
///
/// No usa `StatusBadge` porque ese componente describe estados de habitaciones
/// y reservas, no de personas.
class OwnerStatusChip extends StatelessWidget {
  const OwnerStatusChip({super.key, required this.isActive});

  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppColors.available : AppColors.blocked;
    final label = isActive ? 'Activo' : 'Inactivo';
    return Semantics(
      label: 'Estado: $label',
      child: ExcludeSemantics(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: color.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s3,
              vertical: AppSpacing.s1,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isActive ? Icons.check_circle_outline : Icons.block_outlined,
                  size: 16,
                  color: color,
                ),
                const SizedBox(width: AppSpacing.s1),
                Text(
                  label,
                  style: Theme.of(
                    context,
                  ).textTheme.labelMedium?.copyWith(color: color),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
