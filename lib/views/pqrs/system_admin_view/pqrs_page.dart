import 'package:flutter/material.dart';
import 'package:machuco/controllers/pqrs/pqrs_controller.dart';
import 'package:machuco/core/design_system/design_system.dart';
import 'package:machuco/models/pqrs/pqrs.dart';
import 'package:machuco/widgets/pqrs/pqrs_request_card.dart';
import 'package:machuco/widgets/pqrs/pqrs_stats_panel.dart';
import 'pqrs_detail_page.dart';

/// PQRS view of the system administrator.
///
/// Read-only by design: the administrator picks a motel, reads the statistical
/// behaviour of its PQRS and may open a request to inspect its detail and
/// status, but never intervenes in the traceability.
class SystemAdminPqrsPage extends StatefulWidget {
  const SystemAdminPqrsPage({super.key, this.store});

  final PqrsController? store;

  @override
  State<SystemAdminPqrsPage> createState() => _SystemAdminPqrsPageState();
}

class _SystemAdminPqrsPageState extends State<SystemAdminPqrsPage> {
  String? _motelId;

  PqrsController get _store => widget.store ?? PqrsController.instance;

  void _openDetail(PqrsRequest request) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            SystemAdminPqrsDetailPage(requestId: request.id, store: _store),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('PQRS por motel')),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _store,
          builder: (context, _) {
            final motels = _store.motels;
            if (motels.isEmpty) {
              return const Center(
                child: AppEmptyState(
                  icon: Icons.apartment_outlined,
                  title: 'Sin moteles',
                  message: 'Todavía no hay moteles con solicitudes registradas.',
                ),
              );
            }

            final selectedId = _motelId ?? motels.first.id;
            final requests = _store.byMotel(selectedId);
            final stats = PqrsStats.from(requests);

            return ListView(
              padding: const EdgeInsets.all(AppSpacing.screen),
              children: [
                Text('Supervisión de PQRS', style: theme.textTheme.headlineMedium),
                const SizedBox(height: AppSpacing.s2),
                Text(
                  'Consulta en solo lectura: revisas el detalle, el estado y el '
                  'comportamiento estadístico de cada motel.',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: context.appColors.textSecondary),
                ),
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
                  subtitle: 'Porcentajes calculados sobre las PQRS del motel seleccionado.',
                  highlightLabel: 'Solucionadas',
                  highlightRate: stats.resolutionRate,
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
          },
        ),
      ),
    );
  }
}

class _MotelSelector extends StatelessWidget {
  const _MotelSelector({
    required this.motels,
    required this.selectedId,
    required this.onChanged,
  });

  final List<({String id, String name})> motels;
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
