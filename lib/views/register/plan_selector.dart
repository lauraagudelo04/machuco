import 'package:flutter/material.dart';
import 'package:machuco/core/design_system/design_system.dart';
import 'package:machuco/models/auth/subscription_plan_option.dart';
import 'package:machuco/utils/currency_formatter.dart';

/// Planes de suscripción como tarjetas seleccionables, con sus estados de
/// carga, error (con "Reintentar") y vacío.
class PlanSelector extends StatelessWidget {
  const PlanSelector({
    super.key,
    required this.plans,
    required this.loading,
    required this.errorMessage,
    required this.selectedPlanId,
    required this.onSelected,
    required this.onRetry,
    this.validationError,
  });

  final List<SubscriptionPlanOption> plans;
  final bool loading;
  final String? errorMessage;
  final int? selectedPlanId;
  final ValueChanged<int> onSelected;
  final VoidCallback onRetry;
  final String? validationError;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Widget content;
    if (loading) {
      content = const Column(
        key: ValueKey('plans-loading'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppSkeleton(width: double.infinity, height: AppSpacing.s12),
          SizedBox(height: AppSpacing.s2),
          AppSkeleton(width: double.infinity, height: AppSpacing.s12),
        ],
      );
    } else if (errorMessage != null) {
      content = _PlansMessage(
        key: const ValueKey('plans-error'),
        icon: Icons.error_outline,
        message: errorMessage!,
        onRetry: onRetry,
      );
    } else if (plans.isEmpty) {
      content = _PlansMessage(
        key: const ValueKey('plans-empty'),
        icon: Icons.inbox_outlined,
        message:
            'No hay planes disponibles por ahora. No puedes crear la cuenta '
            'de propietario hasta que haya al menos uno.',
        onRetry: onRetry,
      );
    } else {
      content = Column(
        key: const ValueKey('plans-list'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final plan in plans) ...[
            AppCard(
              key: ValueKey('plan-${plan.id}'),
              selected: plan.id == selectedPlanId,
              semanticLabel: 'Plan ${plan.name ?? ''}'.trim(),
              onTap: () => onSelected(plan.id),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    plan.id == selectedPlanId
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: plan.id == selectedPlanId
                        ? theme.colorScheme.primary
                        : context.appColors.textSecondary,
                  ),
                  const SizedBox(width: AppSpacing.s3),
                  Expanded(child: PlanCardDetails(plan: plan)),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.s2),
          ],
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Plan de suscripción', style: theme.textTheme.bodyLarge),
        const SizedBox(height: AppSpacing.s2),
        content,
        if (validationError != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.s1),
            child: Text(
              validationError!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
      ],
    );
  }
}

class _PlansMessage extends StatelessWidget {
  const _PlansMessage({
    super.key,
    required this.icon,
    required this.message,
    required this.onRetry,
  });

  final IconData icon;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      liveRegion: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: theme.colorScheme.error),
          const SizedBox(width: AppSpacing.s2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(message, style: theme.textTheme.bodyMedium),
                TextButton(
                  onPressed: onRetry,
                  style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Contenido de la tarjeta de un plan: nombre, descripción, precio con
/// periodicidad, máximo de moteles y características. Lo que llegue `null`
/// (o vacío) no se pinta.
class PlanCardDetails extends StatelessWidget {
  const PlanCardDetails({super.key, required this.plan});

  final SubscriptionPlanOption plan;

  String? get _priceLabel {
    final price = plan.price;
    if (price == null) return null;
    final amount = '${formatCurrencyAmount(price)} ${plan.currency ?? 'COP'}';
    final period = plan.billingPeriodLabel;
    return period == null ? amount : '$amount / $period';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondary = context.appColors.textSecondary;
    final maxMotels = plan.maxMotels;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (plan.name case final name?)
          Text(
            name,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        if (plan.description case final description?)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.s1),
            child: Text(
              description,
              style: theme.textTheme.bodyMedium?.copyWith(color: secondary),
            ),
          ),
        if (_priceLabel case final price?)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.s2),
            child: Text(
              price,
              key: ValueKey('plan-${plan.id}-price'),
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        if (maxMotels != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.s1),
            child: Text(
              maxMotels == 1 ? 'Hasta 1 motel' : 'Hasta $maxMotels moteles',
              style: theme.textTheme.bodyMedium,
            ),
          ),
        for (final feature in plan.features)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.s1),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.check,
                  size: AppSpacing.s4,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: AppSpacing.s2),
                Expanded(
                  child: Text(feature, style: theme.textTheme.bodyMedium),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
