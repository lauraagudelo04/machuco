import 'package:flutter/material.dart';
import 'package:machuco/controllers/payment/payment_controller.dart';
import 'package:machuco/core/design_system/design_system.dart';
import 'package:machuco/models/payment/payment.dart';
import 'package:machuco/views/payment/payment_view_support.dart';

class ClientPaymentsPage extends StatefulWidget {
  const ClientPaymentsPage({super.key});

  @override
  State<ClientPaymentsPage> createState() => _ClientPaymentsPageState();
}

class _ClientPaymentsPageState extends State<ClientPaymentsPage> {
  final PaymentController _controller = PaymentController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _controller,
    builder: (context, _) {
      final payments = _controller.clientPayments;
      return Scaffold(
        appBar: AppBar(title: const Text('Mis pagos')),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: payments.isEmpty
                  ? const AppEmptyState(
                      icon: Icons.receipt_long_outlined,
                      title: 'Sin pagos',
                      message:
                          'Tus pagos aparecerán cuando realices una reserva.',
                    )
                  : ListView(
                      padding: const EdgeInsets.all(AppSpacing.screen),
                      children: [
                        Text(
                          'Pagos de mis reservas',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: AppSpacing.s2),
                        Text(
                          'Consulta el estado y el comprobante de tus reservas en cualquier motel.',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: context.appColors.textSecondary,
                              ),
                        ),
                        const SizedBox(height: AppSpacing.s5),
                        ...payments.map(
                          (payment) => Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.s3,
                            ),
                            child: _ClientPaymentCard(payment: payment),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      );
    },
  );
}

class _ClientPaymentCard extends StatelessWidget {
  const _ClientPaymentCard({required this.payment});
  final PaymentRecord payment;

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
                    payment.motel,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppSpacing.s1),
                  Text(
                    payment.bookingReference,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
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
        _DetailRow(icon: Icons.bed_outlined, text: payment.room),
        const SizedBox(height: AppSpacing.s2),
        _DetailRow(
          icon: Icons.event_outlined,
          text: formatPaymentDate(payment.reservationDate),
        ),
        const SizedBox(height: AppSpacing.s2),
        _DetailRow(
          icon: Icons.payments_outlined,
          text: formatPaymentMoney(payment.amount),
        ),
        const SizedBox(height: AppSpacing.s4),
        if (payment.receiptNumber != null)
          AppButton(
            label: 'Ver comprobante',
            icon: Icons.receipt_long_outlined,
            variant: AppButtonVariant.secondary,
            onPressed: () => _showReceipt(context, payment),
          )
        else
          Semantics(
            label: 'Comprobante no disponible para pago pendiente',
            child: Text(
              'El comprobante estará disponible cuando se confirme el pago.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: context.appColors.textSecondary,
              ),
            ),
          ),
      ],
    ),
  );

  void _showReceipt(BuildContext context, PaymentRecord payment) =>
      showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (context) => SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.s5),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Comprobante de pago',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: AppSpacing.s4),
                  _ReceiptLine(label: 'Número', value: payment.receiptNumber!),
                  _ReceiptLine(
                    label: 'Reserva',
                    value: payment.bookingReference,
                  ),
                  _ReceiptLine(label: 'Motel', value: payment.motel),
                  _ReceiptLine(
                    label: 'Valor',
                    value: formatPaymentMoney(payment.amount),
                  ),
                  _ReceiptLine(
                    label: 'Método',
                    value: payment.method == PaymentMethod.cash
                        ? 'Efectivo'
                        : 'Pago en línea',
                  ),
                  if (payment.paidAt != null)
                    _ReceiptLine(
                      label: 'Fecha de pago',
                      value: formatPaymentDate(payment.paidAt!),
                    ),
                  const SizedBox(height: AppSpacing.s2),
                  const PaymentStatusBadge(status: PaymentStatus.paid),
                ],
              ),
            ),
          ),
        ),
      );
}

class _ReceiptLine extends StatelessWidget {
  const _ReceiptLine({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.s2),
    child: Row(
      children: [
        SizedBox(
          width: 112,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: context.appColors.textSecondary,
            ),
          ),
        ),
        Expanded(
          child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
        ),
      ],
    ),
  );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 18, color: context.appColors.textSecondary),
      const SizedBox(width: AppSpacing.s2),
      Expanded(
        child: Text(
          text,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: context.appColors.textSecondary,
          ),
        ),
      ),
    ],
  );
}
