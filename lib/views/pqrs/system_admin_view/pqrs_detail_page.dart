import 'package:flutter/material.dart';
import 'package:machuco/controllers/pqrs/pqrs_controller.dart';
import 'package:machuco/core/design_system/design_system.dart';
import 'package:machuco/models/pqrs/pqrs.dart';
import 'package:machuco/widgets/pqrs/pqrs_presentation.dart';
import 'package:machuco/widgets/pqrs/pqrs_status_badge.dart';
import 'package:machuco/widgets/pqrs/pqrs_timeline.dart';

/// Read-only detail for the system administrator: subject, status, indicators
/// of the request and its full traceability, with no composer at all.
class SystemAdminPqrsDetailPage extends StatelessWidget {
  const SystemAdminPqrsDetailPage({
    super.key,
    required this.requestId,
    this.store,
  });

  final String requestId;
  final PqrsController? store;

  PqrsController get _store => store ?? PqrsController.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detalle de la PQRS')),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _store,
          builder: (context, _) {
            final request = _store.byId(requestId);

            return ListView(
              padding: const EdgeInsets.all(AppSpacing.screen),
              children: [
                const _ReadOnlyBanner(),
                const SizedBox(height: AppSpacing.s4),
                _RequestHeader(request: request),
                const SizedBox(height: AppSpacing.s5),
                PqrsTimeline(request: request),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ReadOnlyBanner extends StatelessWidget {
  const _ReadOnlyBanner();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.s3),
      child: Row(
        children: [
          Icon(Icons.visibility_outlined, color: context.appColors.textSecondary),
          const SizedBox(width: AppSpacing.s3),
          Expanded(
            child: Text(
              'Consulta en solo lectura. La atención corresponde al propietario y '
              'el cierre al cliente.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _RequestHeader extends StatelessWidget {
  const _RequestHeader({required this.request});

  final PqrsRequest request;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final response = request.firstResponseTime;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(request.type.icon, color: theme.colorScheme.primary),
              const SizedBox(width: AppSpacing.s3),
              Expanded(
                child: Text(request.subject, style: theme.textTheme.titleLarge),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s3),
          _MetaLine(label: 'Motel', value: request.motelName),
          _MetaLine(label: 'Cliente', value: request.clientName),
          _MetaLine(label: 'Tipo', value: request.type.label),
          _MetaLine(label: 'Radicada', value: formatPqrsDateTime(request.createdAt)),
          _MetaLine(
            label: 'Primera respuesta',
            value: response == null ? 'Sin respuesta' : '${response.inHours} h',
          ),
          _MetaLine(label: 'Fotos adjuntas', value: '${request.allAttachments.length}'),
          const SizedBox(height: AppSpacing.s3),
          PqrsStatusBadge(status: request.status),
        ],
      ),
    );
  }
}

class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 132,
            child: Text(
              label,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: context.appColors.textSecondary),
            ),
          ),
          Expanded(
            child: Text(value, style: theme.textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
