import 'package:flutter/material.dart';
import 'package:machuco/controllers/pqrs/pqrs_controller.dart';
import 'package:machuco/core/design_system/design_system.dart';
import 'package:machuco/database/repository/pqrs/pqrs_repository.dart';
import 'package:machuco/models/pqrs/pqrs.dart';
import 'package:machuco/widgets/pqrs/pqrs_controller_gate.dart';
import 'package:machuco/widgets/pqrs/pqrs_presentation.dart';
import 'package:machuco/widgets/pqrs/pqrs_request_card.dart';
import 'package:machuco/widgets/pqrs/pqrs_state_views.dart';
import 'package:machuco/widgets/pqrs/pqrs_stats_panel.dart';
import 'pqrs_detail_page.dart';

/// PQRS view of the motel owner: attends the requests filed against their
/// motels, records every step of the traceability and reads "Mi desempeño".
///
/// The owner never closes a request on their own: closing belongs to the
/// client, except when the confirmation deadline expired.
class OwnerPqrsPage extends StatelessWidget {
  const OwnerPqrsPage({super.key, this.controller});

  /// Without it, the controller of the signed-in user is built.
  final PqrsController? controller;

  @override
  Widget build(BuildContext context) {
    return PqrsControllerGate(
      title: 'PQRS de mis moteles',
      expectedRole: PqrsActor.owner,
      controller: controller,
      builder: (context, controller) => _OwnerInbox(controller: controller),
    );
  }
}

class _OwnerInbox extends StatefulWidget {
  const _OwnerInbox({required this.controller});

  final PqrsController controller;

  @override
  State<_OwnerInbox> createState() => _OwnerInboxState();
}

class _OwnerInboxState extends State<_OwnerInbox> {
  PqrsStatus? _filter;

  PqrsController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    // Opening the screen reads the inbox and retries the pending queue.
    _controller.loadRequests();
  }

  void _openDetail(PqrsRequest request) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            OwnerPqrsDetailPage(requestId: request.id, controller: _controller),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('PQRS de mis moteles')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _controller.loadRequests,
          child: ListenableBuilder(
            listenable: _controller,
            builder: (context, _) => ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppSpacing.screen),
              children: _children(context),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _children(BuildContext context) {
    final theme = Theme.of(context);
    final requests = _controller.all;
    final error = _controller.error;

    if (_controller.isLoading && requests.isEmpty) {
      return const [PqrsLoadingSkeleton()];
    }
    if (error != null && requests.isEmpty) {
      return [
        AppErrorState(
          message: error.message,
          onRetry: error.kind == PqrsFailureKind.permission
              ? null
              : _controller.loadRequests,
        ),
      ];
    }

    final stats = PqrsStats.from(requests);
    final visible = _filter == null
        ? requests
        : requests.where((request) => request.status == _filter).toList();

    return [
      Text('Atención de PQRS', style: theme.textTheme.headlineMedium),
      const SizedBox(height: AppSpacing.s2),
      Text(
        'Responde, adjunta el avance con fotos y marca la solicitud como '
        'solucionada. El cierre lo confirma el cliente.',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: context.appColors.textSecondary,
        ),
      ),
      if (_controller.notice case final notice?) ...[
        const SizedBox(height: AppSpacing.s4),
        PqrsInfoBanner(message: notice, icon: Icons.cloud_off_outlined),
      ],
      if (error != null) ...[
        const SizedBox(height: AppSpacing.s4),
        PqrsErrorBanner(
          message: error.message,
          onRetry: error.isRetryable ? _controller.retry : null,
        ),
      ],
      const SizedBox(height: AppSpacing.s5),
      PqrsStatsPanel(
        stats: stats,
        title: 'Mi desempeño',
        subtitle:
            'Indicadores calculados sobre las solicitudes de tus moteles.',
        highlightLabel: 'Solución',
        highlightRate: stats.solutionRate,
      ),
      const SizedBox(height: AppSpacing.s6),
      Text('Bandeja de solicitudes', style: theme.textTheme.headlineSmall),
      const SizedBox(height: AppSpacing.s3),
      _StatusFilter(
        selected: _filter,
        onChanged: (status) => setState(() => _filter = status),
      ),
      const SizedBox(height: AppSpacing.s4),
      if (requests.isEmpty)
        const AppEmptyState(
          icon: Icons.inbox_outlined,
          title: 'Sin solicitudes',
          message: 'Aún no hay solicitudes sobre tus moteles.',
        )
      else if (visible.isEmpty)
        const AppEmptyState(
          icon: Icons.filter_alt_off_outlined,
          title: 'No hay solicitudes con este estado',
          message: 'Elige otro estado o toca "Todas".',
        )
      else
        for (final request in visible)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.s3),
            child: PqrsRequestCard(
              request: request,
              showClient: true,
              sync: _controller.syncOf(request.id),
              overdue: _controller.isOverdue(request),
              onTap: () => _openDetail(request),
              trailingHint: switch (request.status) {
                PqrsStatus.pending => 'Sin atender',
                PqrsStatus.resolved => 'Esperando al cliente',
                _ => null,
              },
            ),
          ),
    ];
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
