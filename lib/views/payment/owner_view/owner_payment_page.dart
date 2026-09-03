import 'package:flutter/material.dart';
import 'package:machuco/controllers/payment/payment_controller.dart';
import 'package:machuco/core/design_system/design_system.dart';
import 'package:machuco/models/payment/payment.dart';
import 'package:machuco/views/payment/payment_view_support.dart';

class OwnerPaymentsPage extends StatefulWidget {
  const OwnerPaymentsPage({super.key});

  @override
  State<OwnerPaymentsPage> createState() => _OwnerPaymentsPageState();
}

class _OwnerPaymentsPageState extends State<OwnerPaymentsPage> {
  late final List<PaymentRecord> _payments = List.of(
    PaymentController.ownerPayments,
  );

  @override
  Widget build(BuildContext context) {
    final finance = PaymentController.ownerFinance;
    final pending = _payments
        .where((payment) => payment.status == PaymentStatus.pending)
        .toList();
    final completed = _payments
        .where((payment) => payment.status != PaymentStatus.pending)
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Finanzas de mi motel')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 920),
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.screen),
              children: [
                Text(
                  finance.name,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: AppSpacing.s2),
                Text(
                  'Resumen financiero del mes actual.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: context.appColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.s4),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth >= 720 ? 4 : 2;
                    final width =
                        (constraints.maxWidth - AppSpacing.s3 * (columns - 1)) /
                        columns;
                    return Wrap(
                      spacing: AppSpacing.s3,
                      runSpacing: AppSpacing.s3,
                      children: [
                        PaymentMetricCard(
                          width: width,
                          icon: Icons.trending_up_outlined,
                          label: 'Ingresos',
                          value: formatPaymentMoney(finance.income),
                        ),
                        PaymentMetricCard(
                          width: width,
                          icon: Icons.receipt_long_outlined,
                          label: 'Pagos recibidos',
                          value: '${finance.paymentsReceived}',
                        ),
                        PaymentMetricCard(
                          width: width,
                          icon: Icons.schedule_outlined,
                          label: 'Por recaudar',
                          value: formatPaymentMoney(
                            pending.fold<int>(
                              0,
                              (sum, item) => sum + item.amount,
                            ),
                          ),
                        ),
                        PaymentMetricCard(
                          width: width,
                          icon: Icons.percent_outlined,
                          label: 'Comisiones',
                          value: formatPaymentMoney(finance.commissions),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.s6),
                _SectionTitle(title: 'Pagos pendientes', count: pending.length),
                const SizedBox(height: AppSpacing.s3),
                if (pending.isEmpty)
                  const AppEmptyState(
                    icon: Icons.check_circle_outline,
                    title: 'Pagos al día',
                    message: 'No hay reservas pendientes de pago.',
                  )
                else
                  ...pending.map(
                    (payment) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.s3),
                      child: _OwnerPaymentCard(
                        payment: payment,
                        onRegisterCash: () => _confirmCashPayment(payment),
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
                    child: _OwnerPaymentCard(payment: payment),
                  ),
                ),
                const SizedBox(height: AppSpacing.s6),
                Text(
                  'Clientes frecuentes',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: AppSpacing.s2),
                Text(
                  'Ordenados por número de reservas en este motel.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: context.appColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.s3),
                ...PaymentController.frequentClients.map(
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

  Future<void> _confirmCashPayment(PaymentRecord payment) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Registrar pago en efectivo',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: AppSpacing.s3),
              Text(
                'Confirma que recibiste ${formatPaymentMoney(payment.amount)} de ${payment.client} para la reserva ${payment.bookingReference}.',
              ),
              const SizedBox(height: AppSpacing.s2),
              Text(
                'Se generará un comprobante de caja automáticamente.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: context.appColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.s5),
              AppButton(
                label: 'Confirmar pago en efectivo',
                icon: Icons.payments_outlined,
                onPressed: () => Navigator.pop(context, true),
              ),
            ],
          ),
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    final index = _payments.indexWhere((item) => item.id == payment.id);
    setState(
      () => _payments[index] = PaymentController.registerCashPayment(payment),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Pago registrado. Comprobante CAJA-${payment.bookingReference} generado.',
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
  const _OwnerPaymentCard({required this.payment, this.onRegisterCash});
  final PaymentRecord payment;
  final VoidCallback? onRegisterCash;

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
        if (payment.receiptNumber != null) ...[
          const SizedBox(height: AppSpacing.s2),
          Text(
            'Comprobante: ${payment.receiptNumber}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: context.appColors.textSecondary,
            ),
          ),
        ],
        if (onRegisterCash != null) ...[
          const SizedBox(height: AppSpacing.s4),
          AppButton(
            label: 'Registrar pago en efectivo',
            icon: Icons.money_outlined,
            variant: AppButtonVariant.secondary,
            onPressed: onRegisterCash,
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
