import 'package:flutter/material.dart';
import 'package:machuco/controllers/pqrs/pqrs_controller.dart';
import 'package:machuco/controllers/pqrs/pqrs_photo_controller.dart';
import 'package:machuco/core/design_system/design_system.dart';
import 'package:machuco/database/repository/pqrs/pqrs_repository.dart';
import 'package:machuco/models/pqrs/pqrs.dart';
import 'package:machuco/utils/pqrs_validator.dart';
import 'package:machuco/widgets/pqrs/pqrs_presentation.dart';
import 'package:machuco/widgets/pqrs/pqrs_state_views.dart';
import 'package:machuco/widgets/pqrs/pqrs_status_badge.dart';
import 'package:machuco/widgets/pqrs/pqrs_sync_notice.dart';
import 'package:machuco/widgets/pqrs/pqrs_timeline.dart';
import 'package:machuco/widgets/pqrs/pqrs_update_composer.dart';

/// Detail of a request the owner has to attend.
///
/// While the request is open the owner may answer, attach progress photos,
/// mark it as solved or reject it. Once solved it waits for the client; the
/// owner can only close it, for lack of answer, after the deadline.
class OwnerPqrsDetailPage extends StatefulWidget {
  const OwnerPqrsDetailPage({
    super.key,
    required this.requestId,
    required this.controller,
    this.photos,
  });

  final String requestId;
  final PqrsController controller;

  /// Photos of the composer; defaults to the composed ones.
  final PqrsPhotoController? photos;

  @override
  State<OwnerPqrsDetailPage> createState() => _OwnerPqrsDetailPageState();
}

class _OwnerPqrsDetailPageState extends State<OwnerPqrsDetailPage> {
  late final PqrsPhotoController _photos;
  late final bool _ownsPhotos;
  List<PqrsAttachment> _downloaded = const [];

  PqrsController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _ownsPhotos = widget.photos == null;
    _photos =
        widget.photos ?? PqrsPhotoController.fromProvider(PqrsActor.owner);
    _load();
  }

  @override
  void dispose() {
    if (_ownsPhotos) _photos.dispose();
    super.dispose();
  }

  /// Reads the detail (which also retries the pending queue) and its photos.
  Future<void> _load() async {
    final found = await _controller.loadDetail(widget.requestId);
    if (!found) return;
    await _refreshPhotos();
  }

  Future<void> _refreshPhotos() async {
    final photos = await _controller.loadPhotos(widget.requestId);
    if (mounted) setState(() => _downloaded = photos);
  }

  Future<bool> _addUpdate(
    String message,
    List<PqrsAttachment> attachments,
  ) async {
    final sent = await _controller.addUpdate(
      requestId: widget.requestId,
      message: message,
      attachments: attachments,
    );
    if (sent) await _refreshPhotos();
    return sent;
  }

  Future<bool> _markResolved(
    String message,
    List<PqrsAttachment> attachments,
  ) async {
    final sent = await _controller.markResolved(
      requestId: widget.requestId,
      message: message,
      attachments: attachments,
    );
    if (sent) {
      await _refreshPhotos();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Marcada como solucionada. El cliente debe confirmar el cierre.',
            ),
          ),
        );
      }
    }
    return sent;
  }

  Future<void> _reject() async {
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => const _RejectDialog(),
    );
    if (reason == null || !mounted) return;

    final rejected = await _controller.reject(
      requestId: widget.requestId,
      message: reason,
    );
    if (rejected && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Solicitud rechazada con la justificación registrada.'),
        ),
      );
    }
  }

  Future<void> _closeByTimeout() async {
    final confirmed = await AppDialog.confirm(
      context,
      title: 'Cerrar por falta de respuesta',
      message:
          'El cliente no confirmó la solución a tiempo. La solicitud se '
          'cerrará y ya no admitirá más mensajes.',
      confirmLabel: 'Cerrar',
    );
    if (!confirmed || !mounted) return;
    await _controller.closeByTimeout(requestId: widget.requestId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Atender PQRS')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
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
    final request = _controller.findById(widget.requestId);
    final error = _controller.error;

    if (request == null) {
      if (_controller.isLoading) return const [PqrsLoadingSkeleton()];
      if (error != null && error.kind != PqrsFailureKind.notFound) {
        return [
          AppErrorState(
            message: error.message,
            onRetry: error.isRetryable ? _controller.retry : null,
          ),
        ];
      }
      return const [
        AppEmptyState(
          icon: Icons.search_off_outlined,
          title: 'Solicitud no encontrada',
          message:
              'La solicitud no existe o no puedes verla. Vuelve al listado.',
        ),
      ];
    }

    final sync = _controller.syncOf(request.id);
    return [
      _RequestHeader(request: request),
      if (_controller.notice case final notice?) ...[
        const SizedBox(height: AppSpacing.s4),
        PqrsInfoBanner(message: notice, icon: Icons.cloud_off_outlined),
      ],
      if (!sync.isSynced) ...[
        const SizedBox(height: AppSpacing.s4),
        PqrsSyncNotice(
          sync: sync,
          busy: _controller.isBusy,
          onRetry: () => _controller.retryPending(requestId: request.id),
          onDiscard: () => _controller.discardPending(request.id),
        ),
      ],
      if (error != null) ...[
        const SizedBox(height: AppSpacing.s4),
        PqrsErrorBanner(
          message: error.message,
          onRetry: error.isRetryable ? _controller.retry : null,
        ),
      ],
      const SizedBox(height: AppSpacing.s5),
      PqrsTimeline(request: request, photos: _downloaded),
      const SizedBox(height: AppSpacing.s6),
      ..._actions(request),
    ];
  }

  List<Widget> _actions(PqrsRequest request) {
    if (request.status.isFinal) {
      return [
        PqrsFinalNotice(
          status: request.status,
          detail: request.closedBy == PqrsClosedBy.ownerTimeout
              ? 'Cerrada por vencimiento del plazo de confirmación.'
              : null,
        ),
      ];
    }

    if (request.status == PqrsStatus.resolved) {
      final deadline = request.confirmationDeadline;
      return [
        PqrsInfoBanner(
          icon: Icons.hourglass_top_outlined,
          message: deadline == null
              ? 'Ya marcaste la solicitud como solucionada. Espera la '
                    'confirmación del cliente.'
              : 'Ya marcaste la solicitud como solucionada. El cliente puede '
                    'confirmarla hasta el ${formatPqrsDate(deadline)}.',
        ),
        if (_controller.isOverdue(request)) ...[
          const SizedBox(height: AppSpacing.s3),
          AppButton(
            label: 'Cerrar por falta de respuesta',
            icon: Icons.lock_clock_outlined,
            variant: AppButtonVariant.secondary,
            loading: _controller.isBusy,
            onPressed: _closeByTimeout,
          ),
        ],
      ];
    }

    return [
      PqrsUpdateComposer(
        key: const ValueKey('pqrs-composer'),
        author: PqrsActor.owner,
        title: 'Registrar avance',
        hint: 'Describe la gestión realizada y adjunta el avance...',
        submitLabel: 'Enviar avance',
        secondaryLabel: 'Marcar como solucionada',
        secondaryIcon: Icons.verified_outlined,
        photos: _photos,
        busy: _controller.isBusy,
        onSubmit: _addUpdate,
        onSecondary: _markResolved,
      ),
      const SizedBox(height: AppSpacing.s4),
      const PqrsInfoBanner(
        icon: Icons.person_outline,
        message:
            'Recuerda: tú marcas la solución, pero el cierre lo confirma el '
            'cliente.',
      ),
      const SizedBox(height: AppSpacing.s3),
      AppButton(
        label: 'Rechazar solicitud',
        icon: Icons.cancel_outlined,
        variant: AppButtonVariant.destructive,
        onPressed: _controller.isBusy ? null : _reject,
      ),
    ];
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
            style: theme.textTheme.bodySmall?.copyWith(
              color: context.appColors.textSecondary,
            ),
          ),
          if (response != null) ...[
            const SizedBox(height: AppSpacing.s1),
            Text(
              'Primera respuesta a las ${response.inHours} h de radicada.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: context.appColors.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.s3),
          PqrsStatusBadge(status: request.status),
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

  String? get _error => _validationAttempted
      ? PqrsValidator.rejectReason(_controller.text)
      : null;

  void _confirm() {
    setState(() => _validationAttempted = true);
    if (PqrsValidator.rejectReason(_controller.text) != null) return;
    Navigator.of(context).pop(_controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Rechazar solicitud'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'El rechazo queda en la trazabilidad y el cliente lo verá. '
              'Explica el motivo (mínimo ${PqrsValidator.rejectReasonMinLength} '
              'caracteres).',
            ),
            const SizedBox(height: AppSpacing.s4),
            AppTextField(
              label: 'Motivo',
              controller: _controller,
              maxLines: 3,
              errorText: _error,
              errorMaxLines: 3,
              onChanged: (_) {
                if (_validationAttempted) setState(() {});
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        TextButton(
          style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
          onPressed: _confirm,
          child: const Text('Rechazar'),
        ),
      ],
    );
  }
}
