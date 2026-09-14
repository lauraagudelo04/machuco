import 'dart:async';

import 'package:flutter/material.dart';

import 'package:machuco/controllers/booking/owner_view/owner_booking_controller.dart';
import 'package:machuco/core/design_system/design_system.dart';
import 'package:machuco/models/booking/booking.dart';
import 'package:machuco/routes/routes.dart';
import 'package:machuco/widgets/booking/reservation_card.dart';
import 'package:machuco/widgets/booking/reservation_filter_bar.dart';
import 'package:machuco/widgets/booking/reservation_summary_metrics.dart';
import 'package:machuco/widgets/layout/responsive_content.dart';

/// "Reservas de mis hoteles": resumen operativo arriba, filtros
/// horizontales (motel, estado, habitación) y la lista de reservas de
/// todos los moteles administrados por el propietario, ordenada por
/// defecto de más reciente a más antigua.
class OwnerReservationsPage extends StatefulWidget {
  const OwnerReservationsPage({super.key});

  @override
  State<OwnerReservationsPage> createState() => _OwnerReservationsPageState();
}

class _OwnerReservationsPageState extends State<OwnerReservationsPage> {
  late final OwnerBookingController _controller;
  String? _motelFilter;
  String? _roomFilter;
  ReservationStatus? _statusFilter;
  bool _hasLoadedOnce = false;
  List<Reservation> _visibleReservations = const [];

  @override
  void initState() {
    super.initState();
    _controller = OwnerBookingController();
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
    await _controller.loadReservations(
      simulateError: simulateError,
      simulateOffline: simulateOffline,
    );
    if (!simulateError && !simulateOffline) {
      _hasLoadedOnce = true;
      await _applyFilters();
    }
  }

  Future<void> _applyFilters() async {
    final result = await _controller.filteredReservations(
      motelId: _motelFilter,
      roomId: _roomFilter,
      status: _statusFilter,
    );
    if (!mounted) return;
    setState(() => _visibleReservations = result);
  }

  void _clearFilters() {
    setState(() {
      _motelFilter = null;
      _roomFilter = null;
      _statusFilter = null;
    });
    unawaited(_applyFilters());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reservas de mis hoteles'),
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
            AppSkeleton(height: 96),
            SizedBox(height: AppSpacing.s4),
            AppSkeleton(height: 48),
            SizedBox(height: AppSpacing.s4),
            AppSkeleton(height: 160),
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

    final summary = _controller.operationalSummary(motelId: _motelFilter);
    final hasAnyReservation = _controller.ownedReservations.isNotEmpty;

    return RefreshIndicator(
      onRefresh: _load,
      child: ResponsiveContent(
        child: ListView(
          children: [
            ReservationSummaryMetrics(
              metrics: [
                ReservationSummaryMetric(
                  icon: Icons.event_note_outlined,
                  label: 'Total de reservas',
                  value: '${summary['total']}',
                ),
                ReservationSummaryMetric(
                  icon: Icons.event_available_outlined,
                  label: 'Activas / próximas',
                  value: '${summary['activeOrUpcoming']}',
                ),
                ReservationSummaryMetric(
                  icon: Icons.hourglass_top_outlined,
                  label: 'Pendientes de pago',
                  value: '${summary['pendingPayment']}',
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s4),
            ReservationFilterBar(
              groups: [
                ReservationFilterGroup(
                  label: 'Motel',
                  selectedValue: _motelFilter,
                  options: [
                    for (final motel in _controller.ownedMotels)
                      ReservationFilterOption(
                        value: motel.id,
                        label: motel.name,
                      ),
                  ],
                  onChanged: (value) {
                    setState(() => _motelFilter = value);
                    unawaited(_applyFilters());
                  },
                ),
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
                    setState(() {
                      _statusFilter = value == null
                          ? null
                          : ReservationStatus.values.firstWhere(
                              (status) => status.name == value,
                            );
                    });
                    unawaited(_applyFilters());
                  },
                ),
                ReservationFilterGroup(
                  label: 'Habitación',
                  selectedValue: _roomFilter,
                  options: [
                    for (final room in _controller.roomOptions)
                      ReservationFilterOption(
                        value: room.roomId,
                        label: room.label,
                      ),
                  ],
                  onChanged: (value) {
                    setState(() => _roomFilter = value);
                    unawaited(_applyFilters());
                  },
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s4),
            if (_visibleReservations.isEmpty)
              AppEmptyState(
                icon: Icons.event_busy_outlined,
                title: hasAnyReservation
                    ? 'Sin resultados'
                    : 'Todavía no hay reservas',
                message: hasAnyReservation
                    ? 'No hay reservas que coincidan con estos filtros.'
                    : 'Cuando tus clientes reserven, las verás aquí.',
                actionLabel: hasAnyReservation ? 'Limpiar filtros' : null,
                onAction: hasAnyReservation ? _clearFilters : null,
              )
            else
              for (final reservation in _visibleReservations)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.s4),
                  child: ReservationCard(
                    reservation: reservation,
                    guestName: reservation.guestName,
                    onTap: () => Navigator.pushNamed(
                      context,
                      AppRoutes.ownerReservationDetail,
                      arguments: reservation.id,
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
