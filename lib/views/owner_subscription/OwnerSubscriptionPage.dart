import 'package:flutter/material.dart';
import 'package:machuco/core/design_system/design_system.dart';

// --- Domain Models ---

class SubscriptionDetails {
  final String id;
  final String planName;
  final String motelName;
  final String amount;
  final String billingPeriod;
  final String nextBillingDate;
  final AppStatus status;
  final List<String> features;

  const SubscriptionDetails({
    required this.id,
    required this.planName,
    required this.motelName,
    required this.amount,
    required this.billingPeriod,
    required this.nextBillingDate,
    required this.status,
    required this.features,
  });
}

class SubscriptionPayment {
  final String id;
  final String date;
  final String amount;
  final String paymentMethod;
  final String reference;
  final AppStatus status;

  const SubscriptionPayment({
    required this.id,
    required this.date,
    required this.amount,
    required this.paymentMethod,
    required this.reference,
    required this.status,
  });
}

// --- Main Page ---

class OwnerSubscriptionPage extends StatefulWidget {
  const OwnerSubscriptionPage({super.key});

  @override
  State<OwnerSubscriptionPage> createState() => _OwnerSubscriptionPageState();
}

class _OwnerSubscriptionPageState extends State<OwnerSubscriptionPage> {
  final SubscriptionDetails _subscription = const SubscriptionDetails(
    id: 'sub-001',
    planName: 'Plan Premium Pro',
    motelName: 'Motel Paraíso Real',
    amount: '\$ 150.000 COP',
    billingPeriod: 'Mensual',
    nextBillingDate: '25 Sep 2026',
    status: AppStatus.active,
    features: [
      'Gestión de hasta 20 habitaciones',
      'Panel de reportes y estadísticas en tiempo real',
      'Visibilidad prioritaria en búsquedas de clientes',
      'Soporte 24/7 y pasarela de pagos integrada',
    ],
  );

  final List<SubscriptionPayment> _payments = [
    const SubscriptionPayment(
      id: 'pay-101',
      date: '25 Ago 2026',
      amount: '\$ 150.000',
      paymentMethod: 'Transferencia Bancaria',
      reference: 'TRANS-99482',
      status: AppStatus.completed,
    ),
    const SubscriptionPayment(
      id: 'pay-100',
      date: '25 Jul 2026',
      amount: '\$ 150.000',
      paymentMethod: 'Tarjeta de Crédito',
      reference: 'TC-***4092',
      status: AppStatus.completed,
    ),
  ];

  void _addPayment(SubscriptionPayment payment) {
    setState(() {
      _payments.insert(0, payment);
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Pago registrado correctamente'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      );
    }
  }

  void _openAddPaymentModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddPaymentSheet(
        defaultAmount: _subscription.amount,
        onSave: _addPayment,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final semantic = context.appColors;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Suscripción'),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.s5),
        children: [
          // 1. Subscription Details Card
          _SubscriptionDetailCard(subscription: _subscription),
          const SizedBox(height: AppSpacing.s6),

          // 2. Action: Register Payment
          AppButton(
            label: 'Ingresar pago',
            icon: Icons.add_card_outlined,
            onPressed: _openAddPaymentModal,
          ),
          const SizedBox(height: AppSpacing.s6),

          // 3. Payment History Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Historial de pagos', style: AppTextStyles.h2),
              Text(
                '${_payments.length} registros',
                style: AppTextStyles.bodySmall.copyWith(
                  color: semantic.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s3),

          if (_payments.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.s6),
              child: Center(
                child: Text(
                  'No hay pagos registrados aún.',
                  style: AppTextStyles.body.copyWith(
                    color: semantic.textSecondary,
                  ),
                ),
              ),
            )
          else
            ..._payments.map(
              (payment) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.s3),
                child: _PaymentCard(payment: payment),
              ),
            ),
        ],
      ),
    );
  }
}

// --- Detail Card Widget ---

class _SubscriptionDetailCard extends StatelessWidget {
  final SubscriptionDetails subscription;

  const _SubscriptionDetailCard({required this.subscription});

  @override
  Widget build(BuildContext context) {
    final semantic = context.appColors;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.s5),
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
                    Text(subscription.planName, style: AppTextStyles.h1),
                    const SizedBox(height: AppSpacing.s1),
                    Text(
                      subscription.motelName,
                      style: AppTextStyles.body.copyWith(
                        color: semantic.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              StatusBadge(
                status: subscription.status,
                size: StatusBadgeSize.small,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s4),
          const Divider(),
          const SizedBox(height: AppSpacing.s3),

          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Monto',
                      style: AppTextStyles.caption.copyWith(
                        color: semantic.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s1),
                    Text(
                      subscription.amount,
                      style: AppTextStyles.h3.copyWith(
                        color: AppColors.purple,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Próximo cobro',
                      style: AppTextStyles.caption.copyWith(
                        color: semantic.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s1),
                    Text(
                      subscription.nextBillingDate,
                      style: AppTextStyles.bodyLarge,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s4),

          Text(
            'Beneficios incluidos',
            style: AppTextStyles.caption.copyWith(
              color: semantic.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.s2),
          ...subscription.features.map(
            (feature) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.s1),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    size: 16,
                    color: AppColors.available,
                  ),
                  const SizedBox(width: AppSpacing.s2),
                  Expanded(
                    child: Text(
                      feature,
                      style: AppTextStyles.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- Payment Card Widget ---

class _PaymentCard extends StatelessWidget {
  final SubscriptionPayment payment;

  const _PaymentCard({required this.payment});

  @override
  Widget build(BuildContext context) {
    final semantic = context.appColors;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(payment.amount, style: AppTextStyles.h3),
              StatusBadge(
                status: payment.status,
                size: StatusBadgeSize.small,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s2),
          Row(
            children: [
              Icon(
                Icons.calendar_today_outlined,
                size: 14,
                color: semantic.textSecondary,
              ),
              const SizedBox(width: AppSpacing.s1),
              Text(
                payment.date,
                style: AppTextStyles.bodySmall.copyWith(
                  color: semantic.textSecondary,
                ),
              ),
              const SizedBox(width: AppSpacing.s4),
              Icon(
                Icons.payment_outlined,
                size: 14,
                color: semantic.textSecondary,
              ),
              const SizedBox(width: AppSpacing.s1),
              Expanded(
                child: Text(
                  payment.paymentMethod,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: semantic.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s1),
          Row(
            children: [
              Icon(
                Icons.tag_outlined,
                size: 14,
                color: semantic.textSecondary,
              ),
              const SizedBox(width: AppSpacing.s1),
              Text(
                'Ref: ${payment.reference}',
                style: AppTextStyles.caption.copyWith(
                  color: semantic.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// --- Modal Bottom Sheet: Add Payment ---

class _AddPaymentSheet extends StatefulWidget {
  final String defaultAmount;
  final ValueChanged<SubscriptionPayment> onSave;

  const _AddPaymentSheet({
    required this.defaultAmount,
    required this.onSave,
  });

  @override
  State<_AddPaymentSheet> createState() => _AddPaymentSheetState();
}

class _AddPaymentSheetState extends State<_AddPaymentSheet> {
  final _amountController = TextEditingController();
  final _referenceController = TextEditingController();
  String _selectedMethod = 'Transferencia Bancaria';

  final List<String> _paymentMethods = [
    'Transferencia Bancaria',
    'Tarjeta de Crédito',
    'PSE / Nequi / Daviplata',
    'Efectivo / Corresponsal',
  ];

  @override
  void initState() {
    super.initState();
    _amountController.text = widget.defaultAmount.replaceAll(' COP', '');
  }

  @override
  void dispose() {
    _amountController.dispose();
    _referenceController.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    final amountText = _amountController.text.trim();
    final refText = _referenceController.text.trim();

    if (amountText.isEmpty) return;

    final newPayment = SubscriptionPayment(
      id: 'pay-${DateTime.now().millisecondsSinceEpoch}',
      date: '${DateTime.now().day} ${_getMonthAbbr(DateTime.now().month)} ${DateTime.now().year}',
      amount: amountText.startsWith('\$') ? amountText : '\$ $amountText',
      paymentMethod: _selectedMethod,
      reference: refText.isEmpty ? 'PAGO-AUTO' : refText,
      status: AppStatus.completed,
    );

    widget.onSave(newPayment);
    Navigator.of(context).pop();
  }

  String _getMonthAbbr(int month) {
    const months = [
      'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
      'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'
    ];
    return months[month - 1];
  }

  @override
  Widget build(BuildContext context) {
    final semantic = context.appColors;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.only(
        left: AppSpacing.s5,
        right: AppSpacing.s5,
        top: AppSpacing.s5,
        bottom: AppSpacing.s5 + bottomInset,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.xl),
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Registrar Pago', style: AppTextStyles.h2),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s4),

            // Amount field
            AppTextField(
              label: 'Monto a pagar',
              controller: _amountController,
              keyboardType: TextInputType.number,
              prefixIcon: const Icon(Icons.attach_money_rounded),
            ),
            const SizedBox(height: AppSpacing.s3),

            // Payment method selector
            Text(
              'Método de pago',
              style: AppTextStyles.caption.copyWith(
                color: semantic.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.s1),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: semantic.border),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedMethod,
                  isExpanded: true,
                  items: _paymentMethods
                      .map(
                        (m) => DropdownMenuItem(
                          value: m,
                          child: Text(m, style: AppTextStyles.body),
                        ),
                      )
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedMethod = val);
                  },
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.s3),

            // Reference field
            AppTextField(
              label: 'Número de comprobante / Referencia',
              controller: _referenceController,
              hint: 'Ej: TRANS-123456',
              prefixIcon: const Icon(Icons.receipt_long_outlined),
            ),
            const SizedBox(height: AppSpacing.s5),

            // Submit Button
            AppButton(
              label: 'Confirmar pago',
              icon: Icons.check_circle_outline,
              onPressed: _handleSubmit,
            ),
            const SizedBox(height: AppSpacing.s2),
          ],
        ),
      ),
    );
  }
}
