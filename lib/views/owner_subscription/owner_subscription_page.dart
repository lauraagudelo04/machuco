import 'package:flutter/material.dart';
import 'package:machuco/controllers/subscription/owner_subscription_controller.dart';
import 'package:machuco/core/design_system/design_system.dart';
import 'package:machuco/widgets/subscription/add_payment_sheet.dart';
import 'package:machuco/widgets/subscription/subscription_detail_card.dart';
import 'package:machuco/widgets/subscription/subscription_payment_card.dart';

class OwnerSubscriptionPage extends StatefulWidget {
  const OwnerSubscriptionPage({super.key});

  @override
  State<OwnerSubscriptionPage> createState() => _OwnerSubscriptionPageState();
}

class _OwnerSubscriptionPageState extends State<OwnerSubscriptionPage> {
  final OwnerSubscriptionController _controller = OwnerSubscriptionController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _openAddPaymentModal() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AddPaymentSheet(
        defaultAmount: _controller.subscription.amount,
        onSave:
            ({
              required int amount,
              required String paymentMethod,
              required String reference,
            }) {
              _controller.addPayment(
                amount: amount,
                paymentMethod: paymentMethod,
                reference: reference,
              );
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
            },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) => _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    final semantic = context.appColors;
    final subscription = _controller.subscription;
    final payments = _controller.payments;

    return Scaffold(
      appBar: AppBar(title: const Text('Suscripción'), centerTitle: false),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 920),
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.screen),
              children: [
                // 1. Subscription Details Card
                SubscriptionDetailCard(subscription: subscription),
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
                      '${payments.length} registros',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: semantic.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s3),

                if (payments.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.s6,
                    ),
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
                  ...payments.map(
                    (payment) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.s3),
                      child: SubscriptionPaymentCard(payment: payment),
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
