import 'package:flutter/material.dart';
import 'package:machuco/controllers/pqrs/pqrs_controller.dart';
import 'package:machuco/controllers/pqrs/pqrs_photo_controller.dart';
import 'package:machuco/controllers/pqrs/pqrs_type_catalog.dart';
import 'package:machuco/core/design_system/design_system.dart';
import 'package:machuco/database/repository/pqrs/pqrs_repository.dart';
import 'package:machuco/models/pqrs/pqrs.dart';
import 'package:machuco/widgets/pqrs/pqrs_presentation.dart';
import 'package:machuco/widgets/pqrs/pqrs_state_views.dart';
import 'package:machuco/widgets/pqrs/pqrs_status_badge.dart';
import 'package:machuco/widgets/pqrs/pqrs_sync_notice.dart';
import 'package:machuco/widgets/pqrs/pqrs_timeline.dart';
import 'package:machuco/widgets/pqrs/pqrs_update_composer.dart';

/// Detail of one of the client's requests.
///
/// The client comments, attaches photos and, only once the owner marked the
/// request as solved, confirms the solution and closes it. Commenting on a
/// solved request reopens it.
class ClientPqrsDetailPage extends StatefulWidget {
  const ClientPqrsDetailPage({
    super.key,
    required this.requestId,
    required this.controller,
    this.catalog,
    this.photos,
  });

  final String requestId;
  final PqrsController controller;

  /// Type catalog for the estimated response date; defaults to the composed one.
  final PqrsTypeCatalog? catalog;

  /// Photos of the comment composer; defaults to the composed ones.
  final PqrsPhotoController? photos;

  @override
  State<ClientPqrsDetailPage> createState() => _ClientPqrsDetailPageState();
}

class _ClientPqrsDetailPageState extends State<ClientPqrsDetailPage> {
  late final PqrsTypeCatalog _catalog;
  late final PqrsPhotoController _photos;
  late final bool _ownsCatalog;
  late final bool _ownsPhotos;
  List<PqrsAttachment> _downloaded = const [];

  PqrsController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _ownsCatalog = widget.catalog == null;
    _ownsPhotos = widget.photos == null;
    _catalog = widget.catalog ?? PqrsTypeCatalog.fromProvider();
    _photos =
        widget.photos ?? PqrsPhotoController.fromProvider(PqrsActor.client);
    _catalog.load();
    _load();
  }

  @override
  void dispose() {
    if (_ownsCatalog) _catalog.dispose();
    if (_ownsPhotos) _photos.dispose();
    super.dispose();
  }

  /// Reads the detail (which also retries the pending queue) and its photos.
  Future<void> _load() async {
    final found = await _controller.loadDetail(widget.requestId);
    if (!found) return;
    final photos = await _controller.loadPhotos(widget.requestId);
    if (mounted) setState(() => _downloaded = photos);
  }

  Future<bool> _addComment(
    String message,
    List<PqrsAttachment> attachments,
  ) async {
    final sent = await _controller.addUpdate(
      requestId: widget.requestId,
      message: message,
      attachments: attachments,
    );
    if (sent) {
      final photos = await _controller.loadPhotos(widget.requestId);
      if (mounted) setState(() => _downloaded = photos);
    }
    return sent;
  }

  Future<void> _close() async {
    final confirmed = await AppDialog.confirm(
      context,
      title: 'Confirmar solución',
      message: 'Se cerrará la solicitud y ya no admitirá más mensajes.',
      confirmLabel: 'Confirmar y cerrar',
    );
    if (!confirmed || !mounted) return;
    final closed = await _controller.closeByClient(requestId: widget.requestId);
    if (closed && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Solicitud cerrada. Gracias por confirmar.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detalle de mi PQRS')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListenableBuilder(
            listenable: Listenable.merge([_controller, _catalog]),
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
      _RequestHeader(
        request: request,
        estimatedResponse: _catalog.estimatedResponse(request),
      ),
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
      return [PqrsFinalNotice(status: request.status)];
    }
    final deadline = request.confirmationDeadline;
    return [
      if (request.canBeClosedByClient) ...[
        _ConfirmationCard(
          deadline: deadline,
          busy: _controller.isBusy,
          onConfirm: _close,
        ),
        const SizedBox(height: AppSpacing.s4),
      ],
      PqrsUpdateComposer(
        key: const ValueKey('pqrs-composer'),
        author: PqrsActor.client,
        title: request.canBeClosedByClient
            ? '¿No quedó resuelta?'
            : 'Responder al propietario',
        hint: request.canBeClosedByClient
            ? 'Cuéntanos qué falta. La solicitud volverá a estar en trámite.'
            : 'Cuenta cómo va la situación o adjunta una foto...',
        submitLabel: 'Enviar comentario',
        photos: _photos,
        busy: _controller.isBusy,
        onSubmit: _addComment,
      ),
      if (!request.canBeClosedByClient) ...[
        const SizedBox(height: AppSpacing.s4),
        PqrsInfoBanner(
          icon: Icons.info_outline,
          message:
              'Podrás cerrar la solicitud cuando el propietario la marque '
              'como solucionada. Ahora está '
              '${request.status.label.toLowerCase()}.',
        ),
      ],
    ];
  }
}

class _RequestHeader extends StatelessWidget {
  const _RequestHeader({
    required this.request,
    required this.estimatedResponse,
  });

  final PqrsRequest request;
  final DateTime estimatedResponse;

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
            '${request.type.label} · ${request.motelName} · '
            'Radicada el ${formatPqrsDate(request.createdAt)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: context.appColors.textSecondary,
            ),
          ),
          if (!request.status.isFinal) ...[
            const SizedBox(height: AppSpacing.s1),
            Text(
              'Respuesta estimada: ${formatPqrsDate(estimatedResponse)}',
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

class _ConfirmationCard extends StatelessWidget {
  const _ConfirmationCard({
    required this.deadline,
    required this.busy,
    required this.onConfirm,
  });

  final DateTime? deadline;
  final bool busy;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'El propietario propuso una solución',
            style: theme.textTheme.titleLarge,
          ),
          if (deadline != null) ...[
            const SizedBox(height: AppSpacing.s2),
            Text(
              'Si no confirmas antes del ${formatPqrsDate(deadline!)}, '
              'el propietario podrá cerrarla',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: context.appColors.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.s4),
          AppButton(
            label: 'Confirmar solución y cerrar',
            icon: Icons.lock_outline,
            loading: busy,
            onPressed: onConfirm,
          ),
        ],
      ),
    );
  }
}
