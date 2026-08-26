import 'package:flutter/material.dart';

import '../../../core/design_system/components/app_feedback.dart';
import '../../../core/design_system/theme/app_theme_extensions.dart';
import '../../../core/design_system/tokens/app_spacing.dart';
import '../data/pqrs_mock_data.dart';
import '../data/pqrs_store.dart';
import '../models/pqrs_models.dart';
import '../widgets/pqrs_request_card.dart';
import '../widgets/pqrs_stats_panel.dart';
import 'pqrs_detail_page.dart';

/// PQRS view of the motel owner: attends the requests filed against the motel,
/// records every step of the traceability and reads the attention indicators.
///
/// The owner never closes a request: closing belongs to the client.
class OwnerPqrsPage extends StatefulWidget {
  const OwnerPqrsPage({super.key, this.store, this.motelId = pqrsDemoOwnerMotelId});

  final PqrsStore? store;
  final String motelId;

  @override
  State<OwnerPqrsPage> createState() => _OwnerPqrsPageState();
}

class _OwnerPqrsPageState extends State<OwnerPqrsPage> {
  PqrsStatus? _filter;

  PqrsStore get _store => widget.store ?? PqrsStore.instance;

  void _openDetail(PqrsRequest request) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => OwnerPqrsDetailPage(requestId: request.id, store: _store),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('PQRS de mi motel')),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _store,
          builder: (context, _) {
            final requests = _store.byMotel(widget.motelId);
            final stats = PqrsStats.from(requests);
            final visible = _filter == null
                ? requests
                : requests.where((request) => request.status == _filter).toList();

            return ListView(
              padding: const EdgeInsets.all(AppSpacing.screen),
              children: [
                Text('Atención de PQRS', style: theme.textTheme.headlineMedium),
                const SizedBox(height: AppSpacing.s2),
                Text(
                  'Responde, adjunta el avance con fotos y marca la solicitud como '
                  'solucionada. El cierre definitivo lo hace el cliente.',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: context.appColors.textSecondary),
                ),
                const SizedBox(height: AppSpacing.s5),
                PqrsStatsPanel(
                  stats: stats,
                  title: 'Mi desempeño en PQRS',
                  subtitle: 'Indicadores calculados sobre las solicitudes de tu motel.',
                  highlightLabel: 'Atendidas',
                  highlightRate: stats.attentionRate,
                ),
                const SizedBox(height: AppSpacing.s6),
                Text('Bandeja de solicitudes', style: theme.textTheme.headlineSmall),
                const SizedBox(height: AppSpacing.s3),
                _StatusFilter(
                  selected: _filter,
                  onChanged: (status) => setState(() => _filter = status),
                ),
                const SizedBox(height: AppSpacing.s4),
                if (visible.isEmpty)
                  const AppEmptyState(
                    icon: Icons.inbox_outlined,
                    title: 'Sin solicitudes',
                    message: 'No hay PQRS que coincidan con el filtro seleccionado.',
                  )
                else
                  ...visible.map(
                    (request) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.s3),
                      child: PqrsRequestCard(
                        request: request,
                        showClient: true,
                        onTap: () => _openDetail(request),
                        trailingHint: request.status == PqrsStatus.pending
                            ? 'Sin atender'
                            : request.status == PqrsStatus.resolved
                                ? 'Esperando al cliente'
                                : null,
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

class _StatusFilter extends StatelessWidget {
  const _StatusFilter({required this.selected, required this.onChanged});

  final PqrsStatus? selected;
  final ValueChanged<PqrsStatus?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.s2,
      runSpacing: AppSpacing.s2,
      children: [
        ChoiceChip(
          label: const Text('Todas'),
          selected: selected == null,
          onSelected: (_) => onChanged(null),
        ),
        for (final status in PqrsStatus.values)
          ChoiceChip(
            avatar: Icon(status.icon, size: 18, color: status.color),
            label: Text(status.label),
            selected: selected == status,
            onSelected: (_) => onChanged(status),
          ),
      ],
    );
  }
}
