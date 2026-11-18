import 'package:flutter/material.dart';
import 'package:machuco/controllers/pqrs/pqrs_controller.dart';
import 'package:machuco/controllers/pqrs/pqrs_form_controller.dart';
import 'package:machuco/core/design_system/design_system.dart';
import 'package:machuco/database/repository/pqrs/pqrs_repository.dart';
import 'package:machuco/models/pqrs/pqrs.dart';
import 'package:machuco/widgets/pqrs/pqrs_controller_gate.dart';
import 'package:machuco/widgets/pqrs/pqrs_request_card.dart';
import 'package:machuco/widgets/pqrs/pqrs_state_views.dart';
import 'pqrs_detail_page.dart';
import 'pqrs_form_page.dart';

/// PQRS view of the client: lists the requests, opens the form to file a new
/// one and is the only profile allowed to confirm a solution and close.
///
/// Without [controller] it builds the one of the signed-in user.
class ClientPqrsPage extends StatelessWidget {
  const ClientPqrsPage({super.key, this.controller, this.formFactory});

  final PqrsController? controller;

  /// Builds the form controller; tests inject a fake one.
  final PqrsFormController Function(PqrsController controller)? formFactory;

  @override
  Widget build(BuildContext context) {
    return PqrsControllerGate(
      title: 'Mis PQRS',
      expectedRole: PqrsActor.client,
      controller: controller,
      builder: (context, controller) =>
          _ClientPqrsList(controller: controller, formFactory: formFactory),
    );
  }
}

class _ClientPqrsList extends StatefulWidget {
  const _ClientPqrsList({required this.controller, this.formFactory});

  final PqrsController controller;
  final PqrsFormController Function(PqrsController controller)? formFactory;

  @override
  State<_ClientPqrsList> createState() => _ClientPqrsListState();
}

class _ClientPqrsListState extends State<_ClientPqrsList> {
  PqrsController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    // Opening the screen reads the list and retries the pending queue.
    _controller.loadRequests();
  }

  Future<void> _openForm() async {
    final form =
        widget.formFactory?.call(_controller) ??
        PqrsFormController.fromProvider(_controller);
    final sent = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => ClientPqrsFormPage(controller: _controller, form: form),
      ),
    );
    form.dispose();
    if (sent == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tu solicitud fue radicada correctamente.'),
        ),
      );
    }
  }

  void _openDetail(PqrsRequest request) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ClientPqrsDetailPage(
          requestId: request.id,
          controller: _controller,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mis PQRS')),
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
    if (_controller.isEmpty) {
      return [
        AppEmptyState(
          icon: Icons.inbox_outlined,
          title: 'Aún no tienes solicitudes',
          message:
              'Cuéntanos qué pasó con una petición, queja, reclamo o '
              'sugerencia.',
          actionLabel: 'Nueva solicitud',
          onAction: _openForm,
        ),
      ];
    }

    final awaitingClosure = requests
        .where((request) => request.canBeClosedByClient)
        .length;
    return [
      Text('Mis solicitudes', style: theme.textTheme.headlineMedium),
      const SizedBox(height: AppSpacing.s4),
      AppButton(
        label: 'Nueva solicitud',
        icon: Icons.add,
        onPressed: _openForm,
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
      if (awaitingClosure > 0) ...[
        const SizedBox(height: AppSpacing.s4),
        _AwaitingClosureBanner(count: awaitingClosure),
      ],
      const SizedBox(height: AppSpacing.s4),
      for (final request in requests)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.s3),
          child: PqrsRequestCard(
            request: request,
            showMotel: true,
            sync: _controller.syncOf(request.id),
            onTap: () => _openDetail(request),
            trailingHint: request.canBeClosedByClient
                ? 'Requiere tu cierre'
                : null,
          ),
        ),
    ];
  }
}

class _AwaitingClosureBanner extends StatelessWidget {
  const _AwaitingClosureBanner({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return PqrsInfoBanner(
      icon: Icons.verified_outlined,
      message: count == 1
          ? 'Tienes 1 solicitud solucionada esperando tu cierre.'
          : 'Tienes $count solicitudes solucionadas esperando tu cierre.',
    );
  }
}
