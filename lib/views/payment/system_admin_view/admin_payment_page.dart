import 'package:flutter/material.dart';
import 'package:machuco/controllers/payment/payment_controller.dart';
import 'package:machuco/core/design_system/design_system.dart';
import 'package:machuco/models/payment/payment.dart';
import 'package:machuco/views/payment/payment_view_support.dart';

class AdminFinancePage extends StatelessWidget {
  const AdminFinancePage({super.key});

  @override
  Widget build(BuildContext context) {
    final motels = PaymentController.motelFinances;
    final income = motels.fold<int>(0, (sum, item) => sum + item.income);
    final payments = motels.fold<int>(
      0,
      (sum, item) => sum + item.paymentsReceived,
    );
    final pending = motels.fold<int>(
      0,
      (sum, item) => sum + item.pendingAmount,
    );
    final commissions = motels.fold<int>(
      0,
      (sum, item) => sum + item.commissions,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Finanzas globales')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 920),
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.screen),
              children: [
                Text(
                  'Resumen de la plataforma',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: AppSpacing.s2),
                Text(
                  'Ingresos, pagos y comisiones de todos los moteles durante el mes actual.',
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
                          value: formatPaymentMoney(income),
                        ),
                        PaymentMetricCard(
                          width: width,
                          icon: Icons.receipt_long_outlined,
                          label: 'Pagos recibidos',
                          value: '$payments',
                        ),
                        PaymentMetricCard(
                          width: width,
                          icon: Icons.schedule_outlined,
                          label: 'Por recaudar',
                          value: formatPaymentMoney(pending),
                        ),
                        PaymentMetricCard(
                          width: width,
                          icon: Icons.percent_outlined,
                          label: 'Comisiones',
                          value: formatPaymentMoney(commissions),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.s6),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Detalle por motel',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                    Text(
                      '${motels.length} moteles',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s3),
                ...motels.map(
                  (motel) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.s3),
                    child: _MotelFinanceCard(finance: motel),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MotelFinanceCard extends StatelessWidget {
  const _MotelFinanceCard({required this.finance});
  final MotelFinance finance;

  @override
  Widget build(BuildContext context) => AppCard(
    semanticLabel: 'Resumen financiero de ${finance.name}',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                finance.name,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            Text(
              '${finance.rooms} habitaciones',
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s4),
        Wrap(
          spacing: AppSpacing.s6,
          runSpacing: AppSpacing.s3,
          children: [
            _FinanceValue(
              label: 'Ingresos',
              value: formatPaymentMoney(finance.income),
            ),
            _FinanceValue(label: 'Pagos', value: '${finance.paymentsReceived}'),
            _FinanceValue(
              label: 'Pendiente',
              value: formatPaymentMoney(finance.pendingAmount),
            ),
            _FinanceValue(
              label: 'Comisión',
              value: formatPaymentMoney(finance.commissions),
            ),
          ],
        ),
      ],
    ),
  );
}

class _FinanceValue extends StatelessWidget {
  const _FinanceValue({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: context.appColors.textSecondary),
      ),
      const SizedBox(height: AppSpacing.s1),
      Text(value, style: Theme.of(context).textTheme.titleMedium),
    ],
  );
}
