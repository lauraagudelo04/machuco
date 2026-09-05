import 'package:flutter/material.dart';
import 'package:machuco/controllers/pqrs/pqrs_controller.dart';
import 'package:machuco/core/design_system/design_system.dart';
import 'package:machuco/models/pqrs/pqrs.dart';
import 'package:machuco/widgets/pqrs/pqrs_presentation.dart';
import 'package:machuco/widgets/pqrs/pqrs_status_badge.dart';
import 'package:machuco/widgets/pqrs/pqrs_timeline.dart';
import 'package:machuco/widgets/pqrs/pqrs_update_composer.dart';

/// Detail of a request the owner has to attend.
///
/// The owner may answer, attach progress photos, mark the request as solved or
/// reject it. Closing stays with the client, so no closing action is offered.
class OwnerPqrsDetailPage extends StatelessWidget {
  const OwnerPqrsDetailPage({super.key, required this.requestId, this.store});

  final String requestId;
  final PqrsController? store;

  PqrsController get _store => store ?? PqrsController.instance;

  void _addUpdate(String message, List<PqrsAttachment> attachments) {
    _store.addUpdate(
      requestId: requestId,
      author: PqrsActor.owner,
      message: message,
      attachments: attachments,
    );
  }

  void _markResolved(
    BuildContext context,
    String message,
    List<PqrsAttachment> attachments,
  ) {
    _store.markResolved(
      requestId: requestId,
      message: message,
      attachments: attachments,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Marcada como solucionada. El cliente debe confirmar el cierre.'),
      ),
    );
  }

  Future<void> _reject(BuildContext context) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => const _RejectDialog(),
    );
    if (reason == null || !context.mounted) return;

    _store.reject(requestId: requestId, message: reason);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Solicitud rechazada con la justificación registrada.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Atender PQRS')),
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
                else ...[
                  PqrsUpdateComposer(
                    author: PqrsActor.owner,
                    title: 'Registrar avance',
                    hint: 'Describe la gestión realizada y adjunta el avance...',
                    submitLabel: 'Enviar avance',
                    secondaryLabel: request.status == PqrsStatus.resolved
                        ? null
                        : 'Marcar como solucionada',
                    secondaryIcon: Icons.verified_outlined,
                    onSubmit: _addUpdate,
                    onSecondary: request.status == PqrsStatus.resolved
                        ? null
                        : (message, attachments) =>
                            _markResolved(context, message, attachments),
                  ),
                  const SizedBox(height: AppSpacing.s4),
                  _ClosureNotice(status: request.status),
                  const SizedBox(height: AppSpacing.s3),
                  AppButton(
                    label: 'Rechazar solicitud',
                    icon: Icons.cancel_outlined,
                    variant: AppButtonVariant.destructive,
                    onPressed: () => _reject(context),
                  ),
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
          Text(
            '${request.type.label} · ${request.clientName} · '
            'Radicada el ${formatPqrsDate(request.createdAt)}',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: context.appColors.textSecondary),
          ),
          if (response != null) ...[
            const SizedBox(height: AppSpacing.s1),
            Text(
              'Primera respuesta a las ${response.inHours} h de radicada.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: context.appColors.textSecondary),
            ),
          ],
          const SizedBox(height: AppSpacing.s3),
          PqrsStatusBadge(status: request.status),
        ],
      ),
    );
  }
}

class _ClosureNotice extends StatelessWidget {
  const _ClosureNotice({required this.status});

  final PqrsStatus status;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.s3),
      child: Row(
        children: [
          Icon(Icons.person_outline, color: context.appColors.textSecondary),
          const SizedBox(width: AppSpacing.s3),
          Expanded(
            child: Text(
              status == PqrsStatus.resolved
                  ? 'Ya marcaste la solicitud como solucionada. Solo el cliente puede cerrarla.'
                  : 'Recuerda: tú marcas la solución, pero el cierre lo hace el cliente.',
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
                  ? 'El cliente cerró esta solicitud. La trazabilidad queda como historial.'
                  : 'Esta solicitud fue rechazada y no admite nuevas actualizaciones.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _RejectDialog extends StatefulWidget {
  const _RejectDialog();

  @override
  State<_RejectDialog> createState() => _RejectDialogState();
}

class _RejectDialogState extends State<_RejectDialog> {
  final _controller = TextEditingController();
  bool _validationAttempted = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _confirm() {
    setState(() => _validationAttempted = true);
    final reason = _controller.text.trim();
    if (reason.isEmpty) return;
    Navigator.of(context).pop(reason);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Rechazar solicitud'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'El rechazo queda en la trazabilidad y el cliente lo verá. '
            'Explica el motivo.',
          ),
          const SizedBox(height: AppSpacing.s4),
          AppTextField(
            label: 'Motivo',
            controller: _controller,
            maxLines: 3,
            errorText: _validationAttempted && _controller.text.trim().isEmpty
                ? 'Campo requerido'
                : null,
            onChanged: (_) {
              if (_validationAttempted) setState(() {});
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        TextButton(onPressed: _confirm, child: const Text('Rechazar')),
      ],
    );
  }
}
