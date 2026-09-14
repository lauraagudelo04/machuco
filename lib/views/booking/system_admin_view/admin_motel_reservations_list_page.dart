import 'dart:async';

import 'package:flutter/material.dart';

import 'package:machuco/controllers/booking/system_admin_view/system_admin_booking_controller.dart';
import 'package:machuco/core/design_system/design_system.dart';
import 'package:machuco/models/motel/motel_model.dart';
import 'package:machuco/routes/routes.dart';
import 'package:machuco/widgets/booking/motel_reservation_kpi_card.dart';
import 'package:machuco/widgets/layout/responsive_content.dart';

/// Listado de moteles de un propietario con KPIs comparativos de reservas,
/// para la "Analítica de reservas del sistema" del Administrador. Recibe
/// [ownerId] como argumento de ruta: la navegación jerárquica previa (lista
/// de propietarios) pertenece a otra rama, así que esta pantalla asume que
/// ya se seleccionó un propietario. Vista de solo lectura.
class AdminMotelReservationsListPage extends StatefulWidget {
  const AdminMotelReservationsListPage({super.key, required this.ownerId});

  final String ownerId;

  @override
  State<AdminMotelReservationsListPage> createState() =>
      _AdminMotelReservationsListPageState();
}

class _AdminMotelReservationsListPageState
    extends State<AdminMotelReservationsListPage> {
  late final SystemAdminBookingController _controller;
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
    await _controller.loadOwnerMotels(
      widget.ownerId,
      simulateError: simulateError,
      simulateOffline: simulateOffline,
    );
    if (!simulateError && !simulateOffline) {
      _hasLoadedOnce = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reservas por motel'),
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
            AppSkeleton(height: 150),
            SizedBox(height: AppSpacing.s4),
            AppSkeleton(height: 150),
            SizedBox(height: AppSpacing.s4),
            AppSkeleton(height: 150),
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

    final motels = _controller.motels;
    if (motels.isEmpty) {
      return const AppEmptyState(
        icon: Icons.storefront_outlined,
        title: 'Sin moteles registrados',
        message:
            'Este propietario todavía no tiene moteles registrados en la '
            'plataforma.',
      );
    }

    final revenues = [
      for (final motel in motels)
        (_controller.kpiFor(motel.id)?['totalRevenue'] as int?) ?? 0,
    ];
    final hasVariation = motels.length > 1 && revenues.toSet().length > 1;
    final maxRevenue = revenues.reduce((a, b) => a > b ? a : b);
    final minRevenue = revenues.reduce((a, b) => a < b ? a : b);

    return RefreshIndicator(
      onRefresh: _load,
      child: ResponsiveContent(
        child: ListView(
          children: [
            for (final motel in motels)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.s4),
                child: _buildMotelCard(
                  motel,
                  hasVariation: hasVariation,
                  maxRevenue: maxRevenue,
                  minRevenue: minRevenue,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMotelCard(
    Motel motel, {
    required bool hasVariation,
    required int maxRevenue,
    required int minRevenue,
  }) {
    final kpi = _controller.kpiFor(motel.id) ?? const <String, dynamic>{};
    final revenue = (kpi['totalRevenue'] as int?) ?? 0;
    final highlight = !hasVariation
        ? MotelKpiHighlight.none
        : revenue == maxRevenue
        ? MotelKpiHighlight.best
        : revenue == minRevenue
        ? MotelKpiHighlight.worst
        : MotelKpiHighlight.none;

    return MotelReservationKpiCard(
      motelName: motel.name,
      city: kpi['city'] as String? ?? 'Sin ciudad registrada',
      totalReservations: kpi['totalReservations'] as int? ?? 0,
      activeReservations: kpi['activeReservations'] as int? ?? 0,
      cancelledReservations: kpi['cancelledReservations'] as int? ?? 0,
      averagePerDay: (kpi['averagePerDay'] as num?)?.toDouble() ?? 0,
      occupancyRate: (kpi['occupancyRate'] as num?)?.toDouble() ?? 0,
      totalRevenue: revenue,
      monthlyAverage: (kpi['monthlyAverage'] as num?)?.toDouble() ?? 0,
      highlight: highlight,
      onTap: () => Navigator.pushNamed(
        context,
        AppRoutes.adminMotelReservationDashboard,
        arguments: motel.id,
      ),
    );
  }
}
