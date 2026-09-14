import 'package:flutter/material.dart';

import 'package:machuco/core/design_system/components/app_card.dart';
import 'package:machuco/core/design_system/theme/app_theme_extensions.dart';
import 'package:machuco/core/design_system/tokens/app_colors.dart';
import 'package:machuco/core/design_system/tokens/app_radius.dart';
import 'package:machuco/core/design_system/tokens/app_spacing.dart';
import 'package:machuco/utils/currency_formatter.dart';

/// Qué tan destacado es un motel dentro de una comparación entre varios,
/// calculada por quien use el widget (p. ej. comparando ingresos totales
/// entre los moteles de un mismo propietario). No es un estado de la
/// reserva ni del motel: es solo una señal visual puntual para esta
/// comparación en lista.
enum MotelKpiHighlight { none, best, worst }

/// Tarjeta comparativa de KPIs de reservas de un motel: ciudad, total,
/// activas, canceladas, promedio por día, tasa de ocupación e ingresos
/// totales, más el promedio mensual de reservas. Pensada para listas donde
/// se compara el desempeño de varios moteles de un mismo propietario
/// (Administrador), pero es un widget genérico de presentación: todos los
/// valores llegan ya calculados desde el controller correspondiente.
class MotelReservationKpiCard extends StatelessWidget {
  const MotelReservationKpiCard({
    super.key,
    required this.motelName,
    required this.city,
    required this.totalReservations,
    required this.activeReservations,
    required this.cancelledReservations,
    required this.averagePerDay,
    required this.occupancyRate,
    required this.totalRevenue,
    required this.monthlyAverage,
    this.highlight = MotelKpiHighlight.none,
    this.onTap,
  });

  final String motelName;
  final String city;
  final int totalReservations;
  final int activeReservations;
  final int cancelledReservations;
  final double averagePerDay;

  /// Tasa de ocupación como fracción entre 0 y 1 (se muestra como
  /// porcentaje).
  final double occupancyRate;
  final int totalRevenue;
  final double monthlyAverage;
  final MotelKpiHighlight highlight;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final highlightColor = switch (highlight) {
      MotelKpiHighlight.best => AppColors.available,
      MotelKpiHighlight.worst => AppColors.rose,
      MotelKpiHighlight.none => null,
    };
    final highlightLabel = switch (highlight) {
      MotelKpiHighlight.best => 'Mejor desempeño',
      MotelKpiHighlight.worst => 'Necesita atención',
      MotelKpiHighlight.none => null,
    };
    final highlightIcon = switch (highlight) {
      MotelKpiHighlight.best => Icons.trending_up,
      MotelKpiHighlight.worst => Icons.trending_down,
      MotelKpiHighlight.none => null,
    };

    return AppCard(
      onTap: onTap,
      semanticLabel:
          'Motel $motelName en $city, $totalReservations reservas totales'
          '${highlightLabel != null ? ', $highlightLabel' : ''}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      motelName,
                      style: Theme.of(context).textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.s1),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 16,
                          color: context.appColors.textSecondary,
                        ),
                        const SizedBox(width: AppSpacing.s1),
                        Expanded(
                          child: Text(
                            city,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: context.appColors.textSecondary,
                                ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (highlightLabel != null &&
                  highlightIcon != null &&
                  highlightColor != null) ...[
                const SizedBox(width: AppSpacing.s2),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s2,
                    vertical: AppSpacing.s1,
                  ),
                  decoration: BoxDecoration(
                    color: highlightColor.withValues(alpha: .14),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(highlightIcon, size: 14, color: highlightColor),
                      const SizedBox(width: AppSpacing.s1),
                      Text(
                        highlightLabel,
                        style: Theme.of(
                          context,
                        ).textTheme.labelSmall?.copyWith(color: highlightColor),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.s3),
          Wrap(
            spacing: AppSpacing.s5,
            runSpacing: AppSpacing.s3,
            children: [
              _KpiTile(
                icon: Icons.event_note_outlined,
                label: 'Total reservas',
                value: '$totalReservations',
              ),
              _KpiTile(
                icon: Icons.event_available_outlined,
                label: 'Activas',
                value: '$activeReservations',
              ),
              _KpiTile(
                icon: Icons.event_busy_outlined,
                label: 'Canceladas',
                value: '$cancelledReservations',
              ),
              _KpiTile(
                icon: Icons.speed_outlined,
                label: 'Promedio/día',
                value: averagePerDay.toStringAsFixed(1),
              ),
              _KpiTile(
                icon: Icons.meeting_room_outlined,
                label: 'Ocupación',
                value: '${(occupancyRate * 100).round()}%',
              ),
              _KpiTile(
                icon: Icons.payments_outlined,
                label: 'Ingresos totales',
                value: formatCurrencyAmount(totalRevenue),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s2),
          Text(
            'Promedio mensual de reservas: ${monthlyAverage.toStringAsFixed(1)}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: context.appColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _KpiTile extends StatelessWidget {
  const _KpiTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 130,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: context.appColors.textSecondary),
              const SizedBox(width: AppSpacing.s1),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.appColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s1),
          Text(value, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}
