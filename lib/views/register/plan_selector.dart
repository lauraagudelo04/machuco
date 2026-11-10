import 'package:flutter/material.dart';
import 'package:machuco/core/design_system/design_system.dart';
import 'package:machuco/models/auth/subscription_plan_option.dart';

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
              semanticLabel: 'Plan ${plan.name}',
              onTap: () => onSelected(plan.id),
              child: Row(
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
                  Expanded(
                    child: Text(
                      plan.name,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
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
