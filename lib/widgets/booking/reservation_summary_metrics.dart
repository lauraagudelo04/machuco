import 'package:flutter/material.dart';

import 'package:machuco/core/design_system/components/app_card.dart';
import 'package:machuco/core/design_system/theme/app_theme_extensions.dart';
import 'package:machuco/core/design_system/tokens/app_spacing.dart';

/// Una métrica ya calculada (valor + etiqueta + icono) para mostrar dentro
/// de [ReservationSummaryMetrics]. Este widget no calcula nada: solo
/// presenta los valores que le pasa quien lo use.
class ReservationSummaryMetric {
  const ReservationSummaryMetric({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;
}

/// Resumen operativo de reservas: una [AppCard] con 3 o más métricas ya
/// calculadas (total, activas/próximas, pendientes de pago, etc.).
/// Reutilizable por Propietario y, más adelante, por Administrador.
class ReservationSummaryMetrics extends StatelessWidget {
  const ReservationSummaryMetrics({super.key, required this.metrics});

  final List<ReservationSummaryMetric> metrics;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Wrap(
        spacing: AppSpacing.s6,
        runSpacing: AppSpacing.s4,
        children: [
          for (final metric in metrics)
            SizedBox(width: 150, child: _MetricTile(metric: metric)),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.metric});

  final ReservationSummaryMetric metric;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(metric.icon, size: 18, color: context.appColors.textSecondary),
            const SizedBox(width: AppSpacing.s1),
            Expanded(
              child: Text(
                metric.label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: context.appColors.textSecondary,
                ),
                maxLines: 2,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s1),
        Text(metric.value, style: Theme.of(context).textTheme.headlineSmall),
      ],
    );
  }
}
