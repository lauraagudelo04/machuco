import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/design_system/components/app_card.dart';
import '../../../core/design_system/theme/app_theme_extensions.dart';
import '../../../core/design_system/tokens/app_radius.dart';
import '../../../core/design_system/tokens/app_spacing.dart';
import '../models/pqrs_models.dart';

/// Statistics module shared by the owner and system administrator views.
///
/// It shows the headline rate as a ring plus the breakdown per status, so both
/// profiles read the same indicators computed by [PqrsStats].
class PqrsStatsPanel extends StatelessWidget {
  const PqrsStatsPanel({
    super.key,
    required this.stats,
    required this.title,
    required this.highlightLabel,
    required this.highlightRate,
    this.subtitle,
  });

  final PqrsStats stats;
  final String title;
  final String? subtitle;

  /// Caption of the ring, e.g. "Atendidas" or "Cerradas por el cliente".
  final String highlightLabel;
  final double highlightRate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleLarge),
          if (subtitle != null) ...[
            const SizedBox(height: AppSpacing.s1),
            Text(
              subtitle!,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: context.appColors.textSecondary),
            ),
          ],
          const SizedBox(height: AppSpacing.s4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _RateRing(rate: highlightRate, label: highlightLabel),
              const SizedBox(width: AppSpacing.s5),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _MetricRow(
                      label: 'Total de solicitudes',
                      value: '${stats.total}',
                    ),
                    _MetricRow(
                      label: 'Tasa de solución',
                      value: _percent(stats.resolutionRate),
                    ),
                    _MetricRow(
                      label: 'Cerradas por el cliente',
                      value: _percent(stats.closureRate),
                    ),
                    _MetricRow(
                      label: 'Primera respuesta',
                      value: _duration(stats.averageFirstResponse),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s5),
          Text('Distribución por estado', style: theme.textTheme.labelLarge),
          const SizedBox(height: AppSpacing.s3),
          for (final status in PqrsStatus.values)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.s3),
              child: _StatusBar(
                status: status,
                count: stats.countOf(status),
                total: stats.total,
              ),
            ),
        ],
      ),
    );
  }
}

String _percent(double rate) => '${(rate * 100).round()}%';

String _duration(Duration? duration) {
  if (duration == null) return 'Sin datos';
  if (duration.inHours < 1) return '${duration.inMinutes} min';
  if (duration.inHours < 48) return '${duration.inHours} h';
  return '${duration.inDays} d';
}

class _RateRing extends StatelessWidget {
  const _RateRing({required this.rate, required this.label});

  final double rate;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: '$label: ${_percent(rate)}',
      child: ExcludeSemantics(
        child: SizedBox(
          width: 116,
          height: 116,
          child: CustomPaint(
            painter: _RingPainter(
              rate: rate,
              track: context.appColors.border,
              progress: theme.colorScheme.primary,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _percent(rate),
                    style: theme.textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: context.appColors.textSecondary),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.rate,
    required this.track,
    required this.progress,
  });

  final double rate;
  final Color track;
  final Color progress;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 10.0;
    final rect = Offset.zero & size;
    final arcRect = rect.deflate(stroke / 2);

    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = track;

    final progressPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = progress;

    canvas.drawArc(arcRect, 0, math.pi * 2, false, trackPaint);
    canvas.drawArc(
      arcRect,
      -math.pi / 2,
      math.pi * 2 * rate.clamp(0.0, 1.0),
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.rate != rate ||
      oldDelegate.track != track ||
      oldDelegate.progress != progress;
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              label,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: context.appColors.textSecondary),
            ),
          ),
          const SizedBox(width: AppSpacing.s2),
          Text(
            value,
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _StatusBar extends StatelessWidget {
  const _StatusBar({
    required this.status,
    required this.count,
    required this.total,
  });

  final PqrsStatus status;
  final int count;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rate = total == 0 ? 0.0 : count / total;

    return Semantics(
      label: '${status.label}: $count de $total, ${_percent(rate)}',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(status.icon, size: 16, color: status.color),
                const SizedBox(width: AppSpacing.s2),
                Expanded(child: Text(status.label, style: theme.textTheme.bodySmall)),
                Text(
                  '$count · ${_percent(rate)}',
                  style: theme.textTheme.labelMedium
                      ?.copyWith(color: context.appColors.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s1),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: LinearProgressIndicator(
                value: rate,
                minHeight: 6,
                backgroundColor: context.appColors.border,
                valueColor: AlwaysStoppedAnimation<Color>(status.color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
