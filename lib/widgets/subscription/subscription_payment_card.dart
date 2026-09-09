import 'package:flutter/material.dart';
import 'package:machuco/core/design_system/design_system.dart';
import 'package:machuco/models/subscription/subscription.dart';
import 'package:machuco/utils/currency_formatter.dart';
import 'package:machuco/utils/date_formatter.dart';

class SubscriptionPaymentCard extends StatelessWidget {
  const SubscriptionPaymentCard({super.key, required this.payment});

  final SubscriptionPayment payment;

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
              Text(
                formatCurrencyAmount(payment.amount),
                style: AppTextStyles.h3,
              ),
              StatusBadge(status: payment.status, size: StatusBadgeSize.small),
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
                '${formatDayMonthLabel(payment.date)} ${payment.date.year}',
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
              Icon(Icons.tag_outlined, size: 14, color: semantic.textSecondary),
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
