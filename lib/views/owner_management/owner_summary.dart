import 'package:flutter/material.dart';

import 'package:machuco/core/design_system/components/app_card.dart';
import 'package:machuco/core/design_system/theme/app_theme_extensions.dart';
import 'package:machuco/core/design_system/tokens/app_spacing.dart';

import 'package:machuco/models/owner_management/owner.dart';
import 'package:machuco/widgets/account_status_chip.dart';

/// Resumen de solo lectura con los datos de un propietario.
///
/// Lo comparten la confirmación de creación y el detalle, para que el usuario
/// vea siempre la misma información con el mismo orden.
class OwnerSummary extends StatelessWidget {
  const OwnerSummary({super.key, required this.owner});

  final Owner owner;

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
          _SummaryRow(label: 'Teléfono', value: owner.phoneWithDialCode),
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
                AccountStatusChip(
                  isActive: owner.isActive,
                  status: owner.accountStatus,
                ),
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
