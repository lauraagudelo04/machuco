import 'package:flutter/material.dart';
import 'package:machuco/controllers/payment/system_admin_view/system_admin_payment_controller.dart';
import 'package:machuco/core/design_system/design_system.dart';
import 'package:machuco/models/payment/payment.dart';
import 'package:machuco/views/payment/payment_view_support.dart';

class AdminFinancePage extends StatefulWidget {
  const AdminFinancePage({super.key});

  @override
  State<AdminFinancePage> createState() => _AdminFinancePageState();
}

class _AdminFinancePageState extends State<AdminFinancePage> {
  final SystemAdminPaymentController _controller =
      SystemAdminPaymentController();

  @override
  void dispose() {
    _controller.dispose();
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
    final motels = _controller.motelFinances;
    String money(int value) =>
        _controller.hasFinanceSnapshot ? formatPaymentMoney(value) : '—';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Finanzas globales'),
        actions: [
          IconButton(
            onPressed: _controller.load,
            tooltip: 'Actualizar finanzas',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
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
                  'Pagos confirmados en Firebase, de todas las fechas. '
                  'El detalle incluye únicamente moteles con movimientos; '
                  'los ingresos no representan utilidad ni incluyen gastos o comisiones.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: context.appColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.s4),
                if (_controller.isLoading) const LinearProgressIndicator(),
                if (_controller.errorMessage case final message?) ...[
                  Text(message),
                  if (_controller.hasFinanceSnapshot)
                    const Text('Se muestra la última consulta confirmada.'),
                  TextButton(
                    onPressed: _controller.load,
                    child: const Text('Reintentar'),
                  ),
                ],
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
                          value: money(_controller.totalIncome),
                        ),
                        PaymentMetricCard(
                          width: width,
                          icon: Icons.receipt_long_outlined,
                          label: 'Pagos recibidos',
                          value: _controller.hasFinanceSnapshot
                              ? '${_controller.totalPaymentsReceived}'
                              : '—',
                        ),
                        PaymentMetricCard(
                          width: width,
                          icon: Icons.schedule_outlined,
                          label: 'Por recaudar',
                          value: money(_controller.totalPendingAmount),
                        ),
                        PaymentMetricCard(
                          width: width,
                          icon: Icons.undo_outlined,
                          label: 'Reembolsos',
                          value: money(_controller.totalRefundedAmount),
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
                      _controller.hasFinanceSnapshot
                          ? '${motels.length} moteles con movimientos'
                          : 'Sin consulta confirmada',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s3),
                if (_controller.hasFinanceSnapshot && motels.isEmpty)
                  const Text('No hay pagos registrados en Firebase.'),
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
              label: 'Reembolsos',
              value: formatPaymentMoney(finance.refundedAmount),
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
