import 'dart:async';

import 'package:flutter/material.dart';

import 'package:machuco/controllers/booking/system_admin_view/system_admin_booking_controller.dart';
import 'package:machuco/core/design_system/design_system.dart';
import 'package:machuco/models/booking/booking.dart';
import 'package:machuco/utils/currency_formatter.dart';
import 'package:machuco/widgets/booking/reservation_filter_bar.dart';
import 'package:machuco/widgets/booking/simple_bar_line_chart.dart';
import 'package:machuco/widgets/layout/responsive_content.dart';

/// Dashboard detallado de reservas de un motel, para la "Analítica de
/// reservas del sistema" del Administrador: total histórico, evolución del
/// último año (filtrable por estado mediante chips) y desglose de pagos por
/// método. Vista de solo lectura, sin acciones de edición ni cancelación.
/// Recibe [motelId] como argumento de ruta.
class AdminMotelReservationDashboardPage extends StatefulWidget {
  const AdminMotelReservationDashboardPage({super.key, required this.motelId});

  final String motelId;

  @override
  State<AdminMotelReservationDashboardPage> createState() =>
      _AdminMotelReservationDashboardPageState();
}

class _AdminMotelReservationDashboardPageState
    extends State<AdminMotelReservationDashboardPage> {
  late final SystemAdminBookingController _controller;
  ReservationStatus? _statusFilter;
  bool _hasLoadedOnce = false;

  @override
  void initState() {
    super.initState();
    _controller = SystemAdminBookingController();
    _controller.addListener(_refresh);
    unawaited(_load());
  }

  @override
  void dispose() {
    _controller.removeListener(_refresh);
    _controller.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _load({
    bool simulateError = false,
    bool simulateOffline = false,
  }) async {
    await _controller.loadMotelDashboard(
      widget.motelId,
      status: _statusFilter,
      simulateError: simulateError,
      simulateOffline: simulateOffline,
    );
    if (!simulateError && !simulateOffline) {
      _hasLoadedOnce = true;
    }
  }

  Future<void> _applyStatusFilter(ReservationStatus? status) async {
    setState(() => _statusFilter = status);
    await _controller.applyEvolutionStatusFilter(widget.motelId, status);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_controller.selectedMotel?.name ?? 'Dashboard de reservas'),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Herramientas de depuración (mock)',
            icon: const Icon(Icons.bug_report_outlined),
            onSelected: (action) {
              switch (action) {
                case 'reload':
                  unawaited(_load());
                case 'error':
                  unawaited(_load(simulateError: true));
                case 'offline':
                  unawaited(_load(simulateOffline: true));
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'reload', child: Text('Recargar')),
              PopupMenuItem(
                value: 'error',
                child: Text('Simular error de carga'),
              ),
              PopupMenuItem(
                value: 'offline',
                child: Text('Simular sin conexión'),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(child: _buildBody(context)),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_controller.isLoading && !_hasLoadedOnce) {
      return ResponsiveContent(
        child: ListView(
          children: const [
            AppSkeleton(height: 100),
            SizedBox(height: AppSpacing.s4),
            AppSkeleton(height: 220),
            SizedBox(height: AppSpacing.s4),
            AppSkeleton(height: 160),
          ],
        ),
      );
    }

    if (_controller.isOffline) {
      return AppErrorState(
        message: 'Estás sin conexión. Revisa tu internet e intenta de nuevo.',
        onRetry: () => unawaited(_load()),
        code: 'OFFLINE',
      );
    }

    if (_controller.errorMessage != null) {
      return AppErrorState(
        message: _controller.errorMessage!,
        onRetry: () => unawaited(_load()),
      );
    }

    final historicalTotal = _controller.historicalTotal;
    final evolution = _controller.evolution;
    final paymentBreakdown = _controller.paymentBreakdown;
    final byMethod =
        (paymentBreakdown['byMethod'] as List<dynamic>?)
            ?.cast<Map<String, dynamic>>() ??
        const <Map<String, dynamic>>[];
    final hasAnyHistory = historicalTotal > 0;

    return RefreshIndicator(
      onRefresh: _load,
      child: ResponsiveContent(
        child: ListView(
          children: [
            AppCard(
              child: Row(
                children: [
                  Icon(
                    Icons.event_note_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: AppSpacing.s3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total histórico de reservas',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: context.appColors.textSecondary,
                              ),
                        ),
                        Text(
                          '$historicalTotal',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.s5),
            Text(
              'Evolución del último año',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.s2),
            ReservationFilterBar(
              groups: [
                ReservationFilterGroup(
                  label: 'Estado',
                  selectedValue: _statusFilter?.name,
                  options: [
                    for (final status in ReservationStatus.values)
                      ReservationFilterOption(
                        value: status.name,
                        label: status.label,
                      ),
                  ],
                  onChanged: (value) {
                    final status = value == null
                        ? null
                        : ReservationStatus.values.firstWhere(
                            (candidate) => candidate.name == value,
                          );
                    unawaited(_applyStatusFilter(status));
                  },
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s3),
            if (!hasAnyHistory)
              const AppEmptyState(
                icon: Icons.show_chart_outlined,
                title: 'Sin historial de reservas',
                message:
                    'Este motel todavía no ha recibido reservas, así que no '
                    'hay evolución que mostrar.',
              )
            else
              AppCard(
                child: SimpleBarLineChart(
                  points: [
                    for (final point in evolution)
                      ChartDataPoint(
                        label: point['label'] as String,
                        value: (point['value'] as num).toDouble(),
                      ),
                  ],
                  semanticLabel: 'Evolución de reservas del último año',
                ),
              ),
            const SizedBox(height: AppSpacing.s5),
            Text(
              'Pagos por método',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.s2),
            if (!hasAnyHistory || byMethod.isEmpty)
              const AppEmptyState(
                icon: Icons.payments_outlined,
                title: 'Sin pagos registrados',
                message:
                    'Todavía no hay reservas pagadas para desglosar por '
                    'método de pago.',
              )
            else
              AppCard(
                child: Column(
                  children: [
                    for (var i = 0; i < byMethod.length; i++) ...[
                      if (i > 0) const Divider(height: AppSpacing.s5),
                      _PaymentMethodRow(
                        method: byMethod[i]['method'] as String,
                        total: byMethod[i]['total'] as int,
                        count: byMethod[i]['count'] as int,
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PaymentMethodRow extends StatelessWidget {
  const _PaymentMethodRow({
    required this.method,
    required this.total,
    required this.count,
  });

  final String method;
  final int total;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(method, style: Theme.of(context).textTheme.titleSmall),
              Text(
                '$count reserva${count == 1 ? '' : 's'} pagada'
                '${count == 1 ? '' : 's'}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: context.appColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        Text(
          formatCurrencyAmount(total),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
