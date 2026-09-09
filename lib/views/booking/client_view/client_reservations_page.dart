import 'dart:async';

import 'package:flutter/material.dart';

import 'package:machuco/controllers/booking/client_view/client_booking_controller.dart';
import 'package:machuco/core/design_system/components/app_feedback.dart';
import 'package:machuco/core/design_system/components/app_skeleton.dart';
import 'package:machuco/core/design_system/theme/app_theme_extensions.dart';
import 'package:machuco/core/design_system/tokens/app_spacing.dart';
import 'package:machuco/routes/routes.dart';
import 'package:machuco/widgets/booking/reservation_card.dart';

/// "Mis reservas": lista de tarjetas del cliente ordenadas de más reciente
/// a más antigua, con filtro por motel/habitación y orden configurable.
class ClientReservationsPage extends StatefulWidget {
  const ClientReservationsPage({super.key});

  @override
  State<ClientReservationsPage> createState() => _ClientReservationsPageState();
}

class _ClientReservationsPageState extends State<ClientReservationsPage> {
  late final ClientBookingController _controller;
  String? _motelFilter;
  String? _roomFilter;
  ReservationSortField _sortField = ReservationSortField.checkIn;
  bool _descending = true;
  bool _hasLoadedOnce = false;

  @override
  void initState() {
    super.initState();
    _controller = ClientBookingController();
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
    if (!simulateError && !simulateOffline) _hasLoadedOnce = true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis reservas'),
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
      return ListView(
        padding: const EdgeInsets.all(AppSpacing.screen),
        children: const [
          AppSkeleton(height: 160),
          SizedBox(height: AppSpacing.s4),
          AppSkeleton(height: 160),
          SizedBox(height: AppSpacing.s4),
          AppSkeleton(height: 160),
        ],
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

    final motelNames = _controller.motelNames;
    final roomLabels = _controller.roomLabelsFor;
    final reservations = _controller.filteredReservations(
      motelName: _motelFilter,
      roomLabel: _roomFilter,
      sortField: _sortField,
      descending: _descending,
    );
    final hasAnyReservation = _controller.reservations.isNotEmpty;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.screen),
        children: [
          _FilterBar(
            motelNames: motelNames,
            roomLabels: roomLabels,
            motelFilter: _motelFilter,
            roomFilter: _roomFilter,
            sortField: _sortField,
            descending: _descending,
            onMotelChanged: (value) => setState(() => _motelFilter = value),
            onRoomChanged: (value) => setState(() => _roomFilter = value),
            onSortFieldChanged: (value) => setState(() => _sortField = value),
            onToggleDirection: () => setState(() => _descending = !_descending),
          ),
          const SizedBox(height: AppSpacing.s4),
          if (reservations.isEmpty)
            AppEmptyState(
              icon: Icons.event_busy_outlined,
              title: hasAnyReservation
                  ? 'Sin resultados'
                  : 'Todavía no tienes reservas',
              message: hasAnyReservation
                  ? 'No hay reservas que coincidan con el filtro seleccionado.'
                  : 'Cuando reserves una habitación, la verás aquí.',
              actionLabel: hasAnyReservation ? 'Limpiar filtros' : null,
              onAction: hasAnyReservation
                  ? () => setState(() {
                      _motelFilter = null;
                      _roomFilter = null;
                    })
                  : null,
            )
          else
            for (final reservation in reservations)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.s4),
                child: ReservationCard(
                  reservation: reservation,
                  onTap: () => Navigator.pushNamed(
                    context,
                    AppRoutes.clientReservationDetail,
                    arguments: reservation.id,
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.motelNames,
    required this.roomLabels,
    required this.motelFilter,
    required this.roomFilter,
    required this.sortField,
    required this.descending,
    required this.onMotelChanged,
    required this.onRoomChanged,
    required this.onSortFieldChanged,
    required this.onToggleDirection,
  });

  final List<String> motelNames;
  final List<String> roomLabels;
  final String? motelFilter;
  final String? roomFilter;
  final ReservationSortField sortField;
  final bool descending;
  final ValueChanged<String?> onMotelChanged;
  final ValueChanged<String?> onRoomChanged;
  final ValueChanged<ReservationSortField> onSortFieldChanged;
  final VoidCallback onToggleDirection;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.s2,
      runSpacing: AppSpacing.s2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        DropdownMenu<String?>(
          label: const Text('Motel'),
          initialSelection: motelFilter,
          onSelected: onMotelChanged,
          dropdownMenuEntries: [
            const DropdownMenuEntry(value: null, label: 'Todos'),
            for (final name in motelNames)
              DropdownMenuEntry(value: name, label: name),
          ],
        ),
        DropdownMenu<String?>(
          label: const Text('Habitación'),
          initialSelection: roomFilter,
          onSelected: onRoomChanged,
          dropdownMenuEntries: [
            const DropdownMenuEntry(value: null, label: 'Todas'),
            for (final label in roomLabels)
              DropdownMenuEntry(value: label, label: label),
          ],
        ),
        DropdownMenu<ReservationSortField>(
          label: const Text('Ordenar por'),
          initialSelection: sortField,
          onSelected: (value) {
            if (value != null) onSortFieldChanged(value);
          },
          dropdownMenuEntries: const [
            DropdownMenuEntry(
              value: ReservationSortField.checkIn,
              label: 'Fecha de entrada',
            ),
            DropdownMenuEntry(
              value: ReservationSortField.createdAt,
              label: 'Fecha de creación',
            ),
            DropdownMenuEntry(
              value: ReservationSortField.total,
              label: 'Total',
            ),
          ],
        ),
        Semantics(
          button: true,
          label: descending ? 'Orden descendente' : 'Orden ascendente',
          child: IconButton(
            tooltip: descending ? 'Orden descendente' : 'Orden ascendente',
            onPressed: onToggleDirection,
            icon: Icon(descending ? Icons.arrow_downward : Icons.arrow_upward),
            style: IconButton.styleFrom(
              minimumSize: const Size.square(48),
              backgroundColor: context.appColors.elevated,
            ),
          ),
        ),
      ],
    );
  }
}
