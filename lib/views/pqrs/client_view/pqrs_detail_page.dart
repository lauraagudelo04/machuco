import 'package:flutter/material.dart';
import 'package:machuco/controllers/pqrs/pqrs_controller.dart';
import 'package:machuco/core/design_system/design_system.dart';
import 'package:machuco/models/pqrs/pqrs.dart';
import 'package:machuco/widgets/pqrs/pqrs_presentation.dart';
import 'package:machuco/widgets/pqrs/pqrs_status_badge.dart';
import 'package:machuco/widgets/pqrs/pqrs_timeline.dart';
import 'package:machuco/widgets/pqrs/pqrs_update_composer.dart';

/// Detail of one of the client's requests.
///
/// The client comments, attaches photos and — only once the owner marked the
/// request as solved — confirms the solution and closes it.
class ClientPqrsDetailPage extends StatelessWidget {
  const ClientPqrsDetailPage({super.key, required this.requestId, this.store});

  final String requestId;
  final PqrsController? store;

  PqrsController get _store => store ?? PqrsController.instance;

  void _addComment(String message, List<PqrsAttachment> attachments) {
    _store.addUpdate(
      requestId: requestId,
      author: PqrsActor.client,
      message: message,
      attachments: attachments,
    );
  }

  void _close(BuildContext context, String message) {
    _store.closeByClient(requestId: requestId, message: message);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Solicitud cerrada. Gracias por confirmar.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detalle de mi PQRS')),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _store,
          builder: (context, _) {
            final request = _store.byId(requestId);

            return ListView(
              padding: const EdgeInsets.all(AppSpacing.screen),
              children: [
                _RequestHeader(request: request),
                const SizedBox(height: AppSpacing.s5),
                PqrsTimeline(request: request),
                const SizedBox(height: AppSpacing.s6),
                if (request.status.isFinal)
                  _FinalNotice(status: request.status)
                else
                  PqrsUpdateComposer(
                    author: PqrsActor.client,
                    title: 'Responder al propietario',
                    hint: 'Cuenta cómo va la situación o adjunta una foto...',
                    submitLabel: 'Enviar comentario',
                    secondaryLabel: request.canBeClosedByClient
                        ? 'Confirmar solución y cerrar'
                        : null,
                    secondaryIcon:
                        request.canBeClosedByClient ? Icons.lock_outline : null,
                    onSubmit: _addComment,
                    onSecondary: request.canBeClosedByClient
                        ? (message, _) => _close(context, message)
                        : null,
                  ),
                if (!request.status.isFinal && !request.canBeClosedByClient) ...[
                  const SizedBox(height: AppSpacing.s4),
                  _ClosureHint(status: request.status),
                ],
              ],
            );
          },
        ),
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
          Text(
            '${request.type.label} · ${request.motelName} · Radicada el ${formatPqrsDate(request.createdAt)}',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: context.appColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.s3),
          PqrsStatusBadge(status: request.status),
        ],
      ),
    );
  }
}

class _ClosureHint extends StatelessWidget {
  const _ClosureHint({required this.status});

  final PqrsStatus status;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.s3),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: context.appColors.textSecondary),
          const SizedBox(width: AppSpacing.s3),
          Expanded(
            child: Text(
              'Podrás cerrar la solicitud cuando el propietario la marque como solucionada. '
              'Ahora está ${status.label.toLowerCase()}.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _FinalNotice extends StatelessWidget {
  const _FinalNotice({required this.status});

  final PqrsStatus status;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          Icon(status.icon, color: status.color),
          const SizedBox(width: AppSpacing.s3),
          Expanded(
            child: Text(
              status == PqrsStatus.closed
                  ? 'Cerraste esta solicitud. Ya no admite nuevos mensajes.'
                  : 'Esta solicitud fue rechazada por el propietario y no admite nuevos mensajes.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
