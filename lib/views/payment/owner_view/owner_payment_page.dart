import 'package:flutter/material.dart';
import 'package:machuco/controllers/payment/owner_view/owner_payment_controller.dart';
import 'package:machuco/core/design_system/design_system.dart';
import 'package:machuco/models/payment/payment.dart';
import 'package:machuco/views/payment/payment_view_support.dart';
import 'package:machuco/views/payment/owner_view/register_local_payment_sheet.dart';

class OwnerPaymentsPage extends StatefulWidget {
  const OwnerPaymentsPage({
    super.key,
    required this.motelId,
    required this.motelName,
    this.controller,
  });

  final String motelId;
  final String motelName;
  final OwnerPaymentController? controller;

  @override
  State<OwnerPaymentsPage> createState() => _OwnerPaymentsPageState();
}

class _OwnerPaymentsPageState extends State<OwnerPaymentsPage> {
  late final OwnerPaymentController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
        widget.controller ?? OwnerPaymentController(motelId: widget.motelId);
  }

  @override
  void dispose() {
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) => _buildPage(context),
    );
  }

  Widget _buildPage(BuildContext context) {
    final pending = _controller.pendingPayments;
    final completed = _controller.completedPayments;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Finanzas de mi motel'),
        actions: [
          IconButton(
            tooltip: 'Actualizar pagos',
            icon: const Icon(Icons.refresh),
            onPressed: _controller.isLoading || _controller.isSaving
                ? null
                : _controller.load,
          ),
        ],
      ),
      body: SafeArea(
        child: _controller.isLoading
            ? const Center(child: CircularProgressIndicator())
            : _controller.errorMessage != null
            ? AppErrorState(
                message: _controller.errorMessage!,
                onRetry: _controller.load,
              )
            : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 920),
                  child: ListView(
                    padding: const EdgeInsets.all(AppSpacing.screen),
                    children: [
                      Text(
                        widget.motelName,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: AppSpacing.s2),
                      Text(
                        'Resumen de pagos guardados en este dispositivo.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: context.appColors.textSecondary,
                        ),
                      ),
                      if (_controller.useDemoData) ...[
                        const SizedBox(height: AppSpacing.s3),
                        const AppCard(
                          child: Text(
                            'Modo demostración: estos ejemplos locales no provienen de reservas reales.',
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.s4),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final columns = constraints.maxWidth >= 720 ? 4 : 2;
                          final width =
                              (constraints.maxWidth -
                                  AppSpacing.s3 * (columns - 1)) /
                              columns;
                          return Wrap(
                            spacing: AppSpacing.s3,
                            runSpacing: AppSpacing.s3,
                            children: [
                              PaymentMetricCard(
                                width: width,
                                icon: Icons.trending_up_outlined,
                                label: 'Ingresos',
                                value: formatPaymentMoney(
                                  _controller.totalIncome,
                                ),
                              ),
                              PaymentMetricCard(
                                width: width,
                                icon: Icons.receipt_long_outlined,
                                label: 'Pagos recibidos',
                                value: '${_controller.paymentsReceived}',
                              ),
                              PaymentMetricCard(
                                width: width,
                                icon: Icons.schedule_outlined,
                                label: 'Por recaudar',
                                value: formatPaymentMoney(
                                  _controller.pendingAmount,
                                ),
                              ),
                              PaymentMetricCard(
                                width: width,
                                icon: Icons.percent_outlined,
                                label: 'Comisiones',
                                value: '—',
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: AppSpacing.s2),
                      Text(
                        'Comisiones no calculadas en esta etapa.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: context.appColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.s6),
                      _SectionTitle(
                        title: 'Pagos pendientes',
                        count: pending.length,
                      ),
                      const SizedBox(height: AppSpacing.s3),
                      if (pending.isEmpty)
                        AppEmptyState(
                          icon: Icons.check_circle_outline,
                          title: _controller.payments.isEmpty
                              ? 'Sin pagos guardados'
                              : 'Pagos al día',
                          message: _controller.payments.isEmpty
                              ? 'Aún no hay pagos en SQLite para este motel.'
                              : 'No hay pagos pendientes de registrar.',
                        )
                      else
                        ...pending.map(
                          (payment) => Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.s3,
                            ),
                            child: _OwnerPaymentCard(
                              key: ValueKey('payment-${payment.id}'),
                              payment: payment,
                              onRegister: () => _registerPayment(payment),
                            ),
                          ),
                        ),
                      const SizedBox(height: AppSpacing.s6),
                      _SectionTitle(
                        title: 'Pagos realizados',
                        count: completed.length,
                      ),
                      const SizedBox(height: AppSpacing.s3),
                      ...completed.map(
                        (payment) => Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.s3),
                          child: _OwnerPaymentCard(
                            key: ValueKey('payment-${payment.id}'),
                            payment: payment,
                            methodName: _controller.methodName(payment),
                          ),
                        ),
                      ),
                      if (_controller.otherPayments.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.s6),
                        _SectionTitle(
                          title: 'Otros estados',
                          count: _controller.otherPayments.length,
                        ),
                        const SizedBox(height: AppSpacing.s3),
                        ..._controller.otherPayments.map(
                          (payment) => Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.s3,
                            ),
                            child: _OwnerPaymentCard(
                              key: ValueKey('payment-${payment.id}'),
                              payment: payment,
                              methodName: _controller.methodName(payment),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.s6),
                      Text(
                        'Clientes frecuentes',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: AppSpacing.s2),
                      Text(
                        'Según los pagos guardados para este motel.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: context.appColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.s3),
                      ..._controller.frequentClients.map(
                        (client) => Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.s3),
                          child: _FrequentClientCard(client: client),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Future<void> _registerPayment(PaymentRecord payment) async {
    final saved = await showModalBottomSheet<PaymentRecord>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      builder: (_) => RegisterLocalPaymentSheet(
        payment: payment,
        loadPaymentMethods: _controller.loadPaymentMethods,
        onSave: (methodId) => _controller.registerLocalPayment(
          paymentId: payment.id,
          paymentMethodId: methodId,
        ),
      ),
    );
    if (saved == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Pago registrado. Comprobante ${saved.receiptNumber ?? saved.id}.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.count});
  final String title;
  final int count;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(title, style: Theme.of(context).textTheme.headlineSmall),
      ),
      Text('$count', style: Theme.of(context).textTheme.labelLarge),
    ],
  );
}

class _OwnerPaymentCard extends StatelessWidget {
  const _OwnerPaymentCard({
    super.key,
    required this.payment,
    this.onRegister,
    this.methodName,
  });
  final PaymentRecord payment;
  final VoidCallback? onRegister;
  final String? methodName;

  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    payment.client,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text(
                    '${payment.bookingReference} · ${payment.room}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: context.appColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.s2),
            PaymentStatusBadge(status: payment.status),
          ],
        ),
        const SizedBox(height: AppSpacing.s3),
        Row(
          children: [
            Expanded(
              child: Text(
                formatPaymentDate(payment.reservationDate),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            Text(
              formatPaymentMoney(payment.amount),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
        if (methodName case final method?) ...[
          const SizedBox(height: AppSpacing.s2),
          Text('Método: $method', style: Theme.of(context).textTheme.bodySmall),
        ],
        if (payment.paidAt case final paidAt?) ...[
          const SizedBox(height: AppSpacing.s2),
          Text(
            'Fecha de pago: ${formatPaymentDate(paidAt)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        if (payment.receiptNumber != null) ...[
          const SizedBox(height: AppSpacing.s2),
          Text(
            'Comprobante: ${payment.receiptNumber}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: context.appColors.textSecondary,
            ),
          ),
        ],
        if (onRegister != null) ...[
          const SizedBox(height: AppSpacing.s4),
          AppButton(
            label: 'Registrar pago',
            icon: Icons.payments_outlined,
            variant: AppButtonVariant.secondary,
            onPressed: onRegister,
          ),
        ],
      ],
    ),
  );
}

class _FrequentClientCard extends StatelessWidget {
  const _FrequentClientCard({required this.client});
  final FrequentClient client;
  @override
  Widget build(BuildContext context) => AppCard(
    child: Row(
      children: [
        CircleAvatar(
          backgroundColor: context.appColors.elevated,
          child: Text(client.initials),
        ),
        const SizedBox(width: AppSpacing.s3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(client.name, style: Theme.of(context).textTheme.titleMedium),
              Text(
                '${client.reservations} reservas',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: context.appColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        Text(
          formatPaymentMoney(client.totalPaid),
          style: Theme.of(context).textTheme.labelLarge,
        ),
      ],
    ),
  );
}
