import 'package:flutter/material.dart';
import 'package:machuco/controllers/pqrs/pqrs_controller.dart';
import 'package:machuco/core/design_system/design_system.dart';
import 'package:machuco/models/pqrs/pqrs.dart';
import 'package:machuco/widgets/pqrs/pqrs_controller_gate.dart';
import 'package:machuco/widgets/pqrs/pqrs_request_card.dart';
import 'package:machuco/widgets/pqrs/pqrs_state_views.dart';
import 'package:machuco/widgets/pqrs/pqrs_stats_panel.dart';
import 'pqrs_detail_page.dart';

/// PQRS view of the system administrator.
///
/// Read-only by design: the administrator picks a motel, reads the statistical
/// behaviour of its PQRS and may open a request to inspect its detail and
/// status, but never intervenes in the traceability.
class SystemAdminPqrsPage extends StatelessWidget {
  const SystemAdminPqrsPage({super.key, this.controller});

  /// Without it, the controller of the signed-in user is built.
  final PqrsController? controller;

  @override
  Widget build(BuildContext context) {
    return PqrsControllerGate(
      title: 'PQRS por motel',
      expectedRole: PqrsActor.systemAdmin,
      controller: controller,
      builder: (context, controller) => _AdminPqrsView(controller: controller),
    );
  }
}

/// Motel that has at least one request, named as its requests name it.
typedef _MotelEntry = ({String id, String name});

class _AdminPqrsView extends StatefulWidget {
  const _AdminPqrsView({required this.controller});

  final PqrsController controller;

  @override
  State<_AdminPqrsView> createState() => _AdminPqrsViewState();
}

class _AdminPqrsViewState extends State<_AdminPqrsView> {
  String? _motelId;

  PqrsController get _store => widget.controller;

  @override
  void initState() {
    super.initState();
    _store.loadRequests();
  }

  void _openDetail(PqrsRequest request) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SystemAdminPqrsDetailPage(
          requestId: request.id,
          controller: _store,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('PQRS por motel')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _store.loadRequests,
          child: ListenableBuilder(
            listenable: _store,
            builder: (context, _) => _body(context),
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    final theme = Theme.of(context);
    final all = _store.all;
    final error = _store.error;

    if (_store.isLoading && all.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(AppSpacing.screen),
        children: const [PqrsLoadingSkeleton()],
      );
    }
    if (error != null && all.isEmpty) {
      return ListView(
        children: [
          AppErrorState(message: error.message, onRetry: _store.loadRequests),
        ],
      );
    }

    final motels = <_MotelEntry>[
      for (final id in _store.motelIdsWithRequests)
        (id: id, name: all.firstWhere((r) => r.motelId == id).motelName),
    ];
    if (motels.isEmpty) {
      return ListView(
        children: const [
          AppEmptyState(
            icon: Icons.apartment_outlined,
            title: 'Sin moteles',
            message: 'Todavía no hay moteles con solicitudes registradas.',
          ),
        ],
      );
    }

    final selectedId = motels.any((m) => m.id == _motelId)
        ? _motelId!
        : motels.first.id;
    final requests = _store.byMotel(selectedId);
    final stats = PqrsStats.from(requests);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.screen),
      children: [
        Text('Supervisión de PQRS', style: theme.textTheme.headlineMedium),
        const SizedBox(height: AppSpacing.s2),
        Text(
          'Consulta en solo lectura: revisas el detalle, el estado y el '
          'comportamiento estadístico de cada motel.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: context.appColors.textSecondary,
          ),
        ),
        if (_store.notice case final notice?) ...[
          const SizedBox(height: AppSpacing.s4),
          PqrsInfoBanner(message: notice, icon: Icons.cloud_off_outlined),
        ],
        const SizedBox(height: AppSpacing.s5),
        _MotelSelector(
          motels: motels,
          selectedId: selectedId,
          onChanged: (id) => setState(() => _motelId = id),
        ),
        const SizedBox(height: AppSpacing.s5),
        PqrsStatsPanel(
          stats: stats,
          title: 'Comportamiento del motel',
          subtitle:
              'Porcentajes calculados sobre las PQRS del motel seleccionado.',
          highlightLabel: 'Solucionadas',
          highlightRate: stats.solutionRate,
        ),
        const SizedBox(height: AppSpacing.s6),
        Text('Solicitudes del motel', style: theme.textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.s3),
        if (requests.isEmpty)
          const AppEmptyState(
            icon: Icons.inbox_outlined,
            title: 'Sin solicitudes',
            message: 'Este motel no tiene PQRS registradas.',
          )
        else
          ...requests.map(
            (request) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.s3),
              child: PqrsRequestCard(
                request: request,
                showClient: true,
                onTap: () => _openDetail(request),
              ),
            ),
          ),
      ],
    );
  }
}

class _MotelSelector extends StatelessWidget {
  const _MotelSelector({
    required this.motels,
    required this.selectedId,
    required this.onChanged,
  });

  final List<_MotelEntry> motels;
  final String selectedId;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Motel', style: theme.textTheme.labelLarge),
          const SizedBox(height: AppSpacing.s2),
          DropdownButtonFormField<String>(
            initialValue: selectedId,
            isExpanded: true,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.apartment_outlined),
            ),
            items: [
              for (final motel in motels)
                DropdownMenuItem<String>(
                  value: motel.id,
                  child: Text(motel.name),
                ),
            ],
            onChanged: (value) {
              if (value != null) onChanged(value);
            },
          ),
        ],
      ),
    );
  }
}
