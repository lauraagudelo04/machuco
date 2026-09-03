import 'package:flutter/material.dart';
import 'package:machuco/controllers/booking/system_admin_view/system_admin_booking_controller.dart';
import 'package:machuco/core/design_system/design_system.dart';
import 'package:machuco/models/booking/booking.dart';
import 'package:machuco/views/booking/booking_view_support.dart';

class SystemAdminBookingHomePage extends StatelessWidget {
  const SystemAdminBookingHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final summaries = SystemAdminBookingController.motelSummaries;
    final total = summaries.fold<int>(
      0,
      (sum, item) => sum + item.totalBookings,
    );
    final average = total / summaries.length;
    final revenue = summaries.fold<int>(
      0,
      (sum, item) => sum + item.totalRevenue,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Analítica de reservas')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.screen),
          children: [
            Text(
              'Resumen del sistema',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: AppSpacing.s2),
            Text(
              'Comparativo visual del rendimiento de reservas por motel.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: context.appColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.s4),
            LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth > 700
                    ? (constraints.maxWidth - AppSpacing.s3 * 2) / 3
                    : (constraints.maxWidth - AppSpacing.s3) / 2;
                return Wrap(
                  spacing: AppSpacing.s3,
                  runSpacing: AppSpacing.s3,
                  children: [
                    _SystemMetric(
                      width: width,
                      icon: Icons.event_note_outlined,
                      label: 'Reservas totales',
                      value: '$total',
                    ),
                    _SystemMetric(
                      width: width,
                      icon: Icons.query_stats_outlined,
                      label: 'Promedio por motel',
                      value: average.toStringAsFixed(1),
                    ),
                    _SystemMetric(
                      width: width,
                      icon: Icons.payments_outlined,
                      label: 'Ingresos estimados',
                      value: formatBookingMoney(revenue),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: AppSpacing.s6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Moteles',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                Text(
                  '${summaries.length} registrados',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s3),
            ...summaries.map(
              (summary) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.s3),
                child: _MotelSummaryCard(summary: summary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SystemMetric extends StatelessWidget {
  const _SystemMetric({
    required this.width,
    required this.icon,
    required this.label,
    required this.value,
  });
  final double width;
  final IconData icon;
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: AppSpacing.s3),
          Text(value, style: Theme.of(context).textTheme.titleLarge),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: context.appColors.textSecondary,
            ),
          ),
        ],
      ),
    ),
  );
}

class _MotelSummaryCard extends StatelessWidget {
  const _MotelSummaryCard({required this.summary});
  final MotelBookingSummary summary;
  @override
  Widget build(BuildContext context) => AppCard(
    onTap: () => _showDetails(context),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    summary.motelName,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text(
                    summary.city,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: context.appColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '${summary.occupancyRate.toStringAsFixed(1)}%',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s3),
        LinearProgressIndicator(
          value: summary.occupancyRate / 100,
          minHeight: 8,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        const SizedBox(height: AppSpacing.s3),
        Wrap(
          spacing: AppSpacing.s5,
          runSpacing: AppSpacing.s2,
          children: [
            Text('${summary.totalBookings} reservas'),
            Text(
              '${summary.averageBookingsPerDay.toStringAsFixed(1)} promedio/día',
            ),
            Text('${summary.cancelledBookings} canceladas'),
          ],
        ),
        const SizedBox(height: AppSpacing.s2),
        Text(
          formatBookingMoney(summary.totalRevenue),
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ],
    ),
  );

  void _showDetails(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              summary.motelName,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.s4),
            Text('Reservas activas: ${summary.activeBookings}'),
            Text('Reservas canceladas: ${summary.cancelledBookings}'),
            Text('Ocupación estimada: ${summary.occupancyRate}%'),
            Text('Promedio diario: ${summary.averageBookingsPerDay}'),
            const SizedBox(height: AppSpacing.s3),
            Text(
              'Los datos son demostrativos y no representan métricas calculadas.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: context.appColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
