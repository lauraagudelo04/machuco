import 'package:flutter/material.dart';
import 'package:machuco/core/design_system/design_system.dart';
import 'package:machuco/models/payment/payment.dart';

String formatPaymentMoney(int amount) {
  final digits = amount.toString();
  final output = StringBuffer();
  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) output.write('.');
    output.write(digits[index]);
  }
  return '\$ $output';
}

String formatPaymentDate(DateTime date) {
  const months = [
    'ene',
    'feb',
    'mar',
    'abr',
    'may',
    'jun',
    'jul',
    'ago',
    'sep',
    'oct',
    'nov',
    'dic',
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

extension PaymentStatusPresentation on PaymentStatus {
  String get label => switch (this) {
    PaymentStatus.pending => 'Pendiente',
    PaymentStatus.paid => 'Pagado',
    PaymentStatus.refunded => 'Reembolsado',
    PaymentStatus.cancelled => 'Cancelado',
  };
  IconData get icon => switch (this) {
    PaymentStatus.pending => Icons.schedule_outlined,
    PaymentStatus.paid => Icons.check_circle_outline,
    PaymentStatus.refunded => Icons.currency_exchange_outlined,
    PaymentStatus.cancelled => Icons.cancel_outlined,
  };
  Color get color => switch (this) {
    PaymentStatus.pending => AppColors.maintenance,
    PaymentStatus.paid => AppColors.available,
    PaymentStatus.refunded => AppColors.reserved,
    PaymentStatus.cancelled => AppColors.rose,
  };
}

class PaymentStatusBadge extends StatelessWidget {
  const PaymentStatusBadge({super.key, required this.status});
  final PaymentStatus status;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Estado del pago: ${status.label}',
    child: ExcludeSemantics(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: status.color.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s3,
            vertical: AppSpacing.s1,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(status.icon, size: 16, color: status.color),
              const SizedBox(width: AppSpacing.s1),
              Text(
                status.label,
                style: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(color: status.color),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class PaymentMetricCard extends StatelessWidget {
  const PaymentMetricCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.width,
  });
  final IconData icon;
  final String label;
  final String value;
  final double width;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: AppSpacing.s3),
          Text(value, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.s1),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: context.appColors.textSecondary,
            ),
          ),
        ],
      ),
    ),
  );
}
