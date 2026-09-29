import 'package:flutter/material.dart';
import 'package:machuco/core/design_system/design_system.dart';
import 'package:machuco/models/booking/booking.dart';
import 'package:machuco/models/payment_method/payment_method_model.dart';
import 'package:machuco/routes/routes.dart';
import 'package:machuco/utils/currency_formatter.dart';
import 'package:machuco/views/payment_method/payment_method_page.dart';

class PaymentMethodSelectionPage extends StatefulWidget {
  const PaymentMethodSelectionPage({
    super.key,
    this.reservation,
    this.amount = 120000,
    this.concept = 'Reserva Suite Deluxe - Motel Fantasía',
    this.onContinue,
  });

  final Reservation? reservation;
  final int amount;
  final String concept;
  final ValueChanged<PaymentMethodModel>? onContinue;

  @override
  State<PaymentMethodSelectionPage> createState() =>
      _PaymentMethodSelectionPageState();
}

class _PaymentMethodSelectionPageState
    extends State<PaymentMethodSelectionPage> {
  bool _isCashSelected = false;

  Reservation? get _reservation => widget.reservation;

  int get _effectiveAmount => _reservation?.total ?? widget.amount;

  String get _effectiveConcept => _reservation != null
      ? 'Reserva ${_reservation!.roomName} - ${_reservation!.motelName}'
      : widget.concept;

  String get _formattedAmount => '${formatCurrencyAmount(_effectiveAmount)} COP';

  void _selectCash() {
    setState(() => _isCashSelected = true);
  }

  void _goToInvoice([PaymentMethodModel? paymentMethod]) {
    final reservation = _reservation;
    if (reservation == null) {
      Navigator.of(context).pushNamedAndRemoveUntil(
        AppRoutes.clientMotels,
        (_) => false,
      );
      return;
    }

    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRoutes.invoice,
      (_) => false,
      arguments: {
        'reservation': reservation,
        'paymentMethod': paymentMethod ??
            PaymentMethodModel(
              amount: _effectiveAmount,
              concept: _effectiveConcept,
            ),
      },
    );
  }

  void _openCardPayment() {
    setState(() => _isCashSelected = false);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PaymentMethodPage(
          amount: _effectiveAmount,
          concept: _effectiveConcept,
          reservation: _reservation,
          onContinue: widget.onContinue ?? _goToInvoice,
        ),
      ),
    );
  }

  void _finishCashPayment() {
    _goToInvoice();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Scaffold(
      appBar: AppBar(title: const Text('Método de pago'), centerTitle: true),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.s5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total de la reserva',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s1),
                    Text(
                      _formattedAmount,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: AppSpacing.s1),
                    Text(
                      _effectiveConcept,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: colors.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.s6),
              Text(
                '¿Cómo deseas pagar?',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: AppSpacing.s1),
              Text(
                'Selecciona el método de pago para tu reserva.',
                style: TextStyle(color: colors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.s4),
              _PaymentOptionCard(
                icon: Icons.payments_outlined,
                title: 'Efectivo',
                description: 'Paga el valor total en la recepción.',
                selected: _isCashSelected,
                onTap: _selectCash,
              ),
              const SizedBox(height: AppSpacing.s3),
              _PaymentOptionCard(
                icon: Icons.credit_card_outlined,
                title: 'Tarjeta',
                description: 'Realiza el pago en línea con tu tarjeta.',
                selected: false,
                onTap: _openCardPayment,
              ),
              if (_isCashSelected) ...[
                const SizedBox(height: AppSpacing.s5),
                _CashPaymentNotice(formattedAmount: _formattedAmount),
                const SizedBox(height: AppSpacing.s5),
                AppButton(label: 'Finalizar', onPressed: _finishCashPayment),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CashPaymentNotice extends StatelessWidget {
  const _CashPaymentNotice({required this.formattedAmount});

  final String formattedAmount;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.s5),
      decoration: BoxDecoration(
        color: AppColors.violet.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.violet.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.s3),
                decoration: BoxDecoration(
                  color: AppColors.violet.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.storefront_outlined,
                  color: AppColors.violet,
                ),
              ),
              const SizedBox(width: AppSpacing.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pago en recepción',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s1),
                    Text(
                      'Paga cuando llegues al establecimiento.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.s4),
            decoration: BoxDecoration(
              color: colors.elevated,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: colors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TOTAL A PAGAR EN RECEPCIÓN',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colors.textMuted,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSpacing.s1),
                Text(
                  formattedAmount,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.s4),
          Divider(height: 1, color: colors.borderStrong),
          const SizedBox(height: AppSpacing.s4),
          Text(
            'Muchas gracias por usar nuestros servicios. Estaremos listos '
            'para recibirte.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _PaymentOptionCard extends StatelessWidget {
  const _PaymentOptionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return AppCard(
      onTap: onTap,
      selected: selected,
      semanticLabel: '$title. $description',
      child: Row(
        children: [
          Icon(icon, color: AppColors.violet, size: 28),
          const SizedBox(width: AppSpacing.s4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSpacing.s1),
                Text(
                  description,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: colors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.s3),
          Icon(
            selected ? Icons.check_circle : Icons.chevron_right,
            color: selected ? AppColors.violet : colors.textSecondary,
          ),
        ],
      ),
    );
  }
}
