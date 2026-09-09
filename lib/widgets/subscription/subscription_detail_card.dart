import 'package:flutter/material.dart';
import 'package:machuco/core/design_system/design_system.dart';
import 'package:machuco/models/subscription/subscription.dart';
import 'package:machuco/utils/currency_formatter.dart';
import 'package:machuco/utils/date_formatter.dart';

class SubscriptionDetailCard extends StatelessWidget {
  const SubscriptionDetailCard({super.key, required this.subscription});

  final SubscriptionDetails subscription;

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
                      '${formatCurrencyAmount(subscription.amount)} COP',
                      style: AppTextStyles.h3.copyWith(color: AppColors.purple),
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
                      '${formatDayMonthLabel(subscription.nextBillingDate)} ${subscription.nextBillingDate.year}',
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
                    child: Text(feature, style: AppTextStyles.bodySmall),
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
