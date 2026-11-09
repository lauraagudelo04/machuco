import 'package:flutter/material.dart';
import 'package:machuco/controllers/auth/admin_access_controller.dart';
import 'package:machuco/core/design_system/design_system.dart';
import 'package:machuco/models/auth/owner_approval_request.dart';
import 'package:machuco/models/auth/owner_request_alert.dart';
import 'package:machuco/models/auth/person_type.dart';
import 'package:machuco/views/admin_access/owner_application_format.dart';
import 'package:machuco/widgets/auth/auth_notice.dart';
import 'package:machuco/widgets/auth/reject_owner_sheet.dart';
import 'package:machuco/widgets/layout/responsive_content.dart';

/// Argumentos de ruta del detalle: solo el identificador y el controlador
/// compartido con la lista (no se envía el modelo completo).
class OwnerApprovalDetailArgs {
  const OwnerApprovalDetailArgs({required this.uid, required this.controller});

  final String uid;
  final AdminAccessController controller;
}

/// Detalle de una solicitud de propietario con "Aprobar" y "Rechazar".
class OwnerApprovalDetailPage extends StatefulWidget {
  const OwnerApprovalDetailPage({
    super.key,
    required this.uid,
    required this.controller,
  });

  final String uid;
  final AdminAccessController controller;

  @override
  State<OwnerApprovalDetailPage> createState() =>
      _OwnerApprovalDetailPageState();
}

class _OwnerApprovalDetailPageState extends State<OwnerApprovalDetailPage> {
  // Se conserva al abrir: al atenderla, el controlador la quita de la lista.
  late final OwnerApplication? _application = widget.controller.findPending(
    widget.uid,
  );

  AdminAccessController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    // Las alertas solo informan; se piden tras el primer frame para no
    // notificar al controlador compartido mientras se construye el árbol.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final application = _application;
      if (mounted && application != null) _controller.loadAlerts(application);
    });
  }

  Future<void> _approve() async {
    final application = _application;
    if (application == null) return;
    final alerts = _controller.alertsFor(widget.uid);
    final name = ownerApplicationTitle(application);
    final confirmed = await AppDialog.confirm(
      context,
      title: alerts != null && alerts.isNotEmpty
          ? 'Aprobar con advertencias'
          : 'Aprobar solicitud',
      message: alerts != null && alerts.isNotEmpty
          ? '¿Aprobar la cuenta de $name? Revisa estas advertencias:\n'
                '${alerts.alerts.map((a) => '• ${a.message}').join('\n')}'
          : '¿Aprobar la cuenta de $name? '
                'Podrá ingresar como propietario de inmediato.',
      confirmLabel: 'Aprobar',
    );
    if (!confirmed || !mounted) return;
    await _resolve(
      () => _controller.approveOwner(widget.uid),
      successMessage: 'Solicitud aprobada.',
    );
  }

  Future<void> _reject() async {
    final reason = await showRejectOwnerSheet(context);
    if (reason == null || !mounted) return;
    await _resolve(
      () => _controller.rejectOwner(widget.uid, reason: reason),
      successMessage: 'Solicitud rechazada.',
    );
  }

  Future<void> _resolve(
    Future<bool> Function() action, {
    required String successMessage,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final errorColor = Theme.of(context).colorScheme.error;
    final ok = await action();
    if (ok) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(successMessage)));
      navigator.pop();
      return;
    }
    final error = _controller.error ?? 'No pudimos completar la operación.';
    final alreadyHandled = error.contains('ya fue atendida');
    _controller.clearError();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: alreadyHandled ? null : errorColor,
        ),
      );
    if (alreadyHandled) {
      // Vuelve a la lista ya refrescada.
      _controller.loadPendingOwners();
      navigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final application = _application;
    return Scaffold(
      appBar: AppBar(title: const Text('Detalle de la solicitud')),
      body: SafeArea(
        child: application == null
            ? AppEmptyState(
                icon: Icons.task_alt_outlined,
                title: 'Solicitud no disponible',
                message: 'Esta solicitud ya no está pendiente.',
                actionLabel: 'Volver a la lista',
                onAction: () => Navigator.of(context).pop(),
              )
            : SingleChildScrollView(
                child: ResponsiveContent(
                  maxWidth: 560,
                  padding: const EdgeInsets.all(AppSpacing.s4),
                  child: ListenableBuilder(
                    listenable: _controller,
                    builder: (context, _) =>
                        _buildContent(context, application),
                  ),
                ),
              ),
      ),
    );
  }

  /// Advertencias informativas: nunca bloquean "Aprobar".
  Widget _buildAlerts(BuildContext context) {
    if (_controller.isCheckingAlerts(widget.uid)) {
      return const _AlertsChecking();
    }
    final alerts = _controller.alertsFor(widget.uid);
    if (alerts == null || alerts.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              'Revisa antes de aprobar',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          const SizedBox(height: AppSpacing.s2),
          for (final alert in alerts.alerts) ...[
            AuthNotice(
              message: alert.message,
              tone: alert.type == OwnerRequestAlertType.verificationUnavailable
                  ? AuthNoticeTone.info
                  : AuthNoticeTone.error,
              icon: alert.type == OwnerRequestAlertType.verificationUnavailable
                  ? Icons.wifi_off_outlined
                  : Icons.warning_amber_outlined,
            ),
            const SizedBox(height: AppSpacing.s2),
          ],
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, OwnerApplication application) {
    final busy = _controller.isSubmitting;
    final plan = application.planId;
    final rows = <(String, String)>[
      ('Nombre', application.fullName),
      ('Tipo de persona', application.personType?.label ?? 'No indicado'),
      ('NIT', application.nit ?? 'No indicado'),
      if (application.personType == PersonType.juridica)
        ('Razón social', application.companyName ?? 'No indicada'),
      ('Correo', application.email),
      ('Celular', application.phoneNumber),
      ('Plan', plan == null ? 'No indicado' : 'Plan n.º $plan'),
      ('Fecha de solicitud', formatApplicationDate(application.createdAt)),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (label, value) in rows) _DetailRow(label, value),
            ],
          ),
        ),
        _buildAlerts(context),
        const SizedBox(height: AppSpacing.s5),
        AppButton(
          label: 'Aprobar',
          icon: Icons.check,
          loading: busy,
          onPressed: busy ? null : _approve,
        ),
        const SizedBox(height: AppSpacing.s3),
        AppButton(
          label: 'Rechazar',
          icon: Icons.close,
          variant: AppButtonVariant.destructive,
          onPressed: busy ? null : _reject,
        ),
      ],
    );
  }
}

class _AlertsChecking extends StatelessWidget {
  const _AlertsChecking();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.s4),
      child: Semantics(
        liveRegion: true,
        child: Row(
          children: [
            const SizedBox.square(
              dimension: AppSpacing.s5,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: AppSpacing.s2),
            Expanded(
              child: Text(
                'Comprobando los datos de la solicitud…',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s3),
      child: Semantics(
        label: '$label: $value',
        excludeSemantics: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: context.appColors.textMuted,
              ),
            ),
            Text(value, style: theme.textTheme.bodyLarge),
          ],
        ),
      ),
    );
  }
}
