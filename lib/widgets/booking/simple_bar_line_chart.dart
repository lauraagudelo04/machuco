import 'package:flutter/material.dart';

import 'package:machuco/core/design_system/theme/app_theme_extensions.dart';
import 'package:machuco/core/design_system/tokens/app_radius.dart';
import 'package:machuco/core/design_system/tokens/app_spacing.dart';

/// Un punto de datos genérico para [SimpleBarLineChart]: una etiqueta (p.
/// ej. un mes) y un valor numérico ya calculado por quien use el widget.
class ChartDataPoint {
  const ChartDataPoint({required this.label, required this.value});

  final String label;
  final double value;
}

/// Gráfico de barras simple construido solo con primitivas de Flutter, sin
/// dependencias de terceros (el proyecto no tiene aprobada ninguna
/// librería de gráficos, p. ej. `fl_chart`). Dibuja una barra proporcional
/// al valor máximo de la serie por cada [ChartDataPoint]. No tiene
/// interactividad propia (arrastre, zoom, tooltips táctiles): cualquier
/// filtro se aplica externamente recalculando la lista de puntos que se le
/// pasa (p. ej. desde chips de estado).
///
/// Si [points] está vacío, este widget no renderiza nada: quien lo use debe
/// envolverlo con `AppEmptyState` para explicar la ausencia de datos, en
/// vez de mostrar un gráfico vacío sin contexto.
class SimpleBarLineChart extends StatelessWidget {
  const SimpleBarLineChart({
    super.key,
    required this.points,
    this.height = 200,
    this.barColor,
    this.semanticLabel,
  });

  final List<ChartDataPoint> points;
  final double height;
  final Color? barColor;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) return const SizedBox.shrink();

    final maxValue = points.fold<double>(
      0,
      (max, point) => point.value > max ? point.value : max,
    );
    final safeMax = maxValue <= 0 ? 1.0 : maxValue;
    final color = barColor ?? Theme.of(context).colorScheme.primary;

    return Semantics(
      label: semanticLabel ?? 'Gráfico de evolución',
      container: true,
      child: SizedBox(
        height: height,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: points.length,
          separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.s2),
          itemBuilder: (context, index) => SizedBox(
            width: 44,
            child: _Bar(
              point: points[index],
              ratio: points[index].value / safeMax,
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.point, required this.ratio, required this.color});

  final ChartDataPoint point;
  final double ratio;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${point.label}: ${point.value.toStringAsFixed(0)}',
      child: ExcludeSemantics(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              point.value.toStringAsFixed(0),
              style: Theme.of(context).textTheme.labelSmall,
              maxLines: 1,
            ),
            const SizedBox(height: AppSpacing.s1),
            Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: FractionallySizedBox(
                  heightFactor: ratio.clamp(0.02, 1.0),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(AppRadius.sm),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.s1),
            Text(
              point.label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: context.appColors.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
