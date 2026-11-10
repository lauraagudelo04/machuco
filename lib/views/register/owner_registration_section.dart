import 'package:flutter/material.dart';
import 'package:machuco/controllers/auth/validators/auth_validators.dart';
import 'package:machuco/core/design_system/design_system.dart';
import 'package:machuco/models/auth/person_type.dart';
import 'package:machuco/models/auth/subscription_plan_option.dart';
import 'package:machuco/views/register/plan_selector.dart';

/// Bloque propio del Propietario: tipo de persona, NIT, razón social (solo
/// jurídica) y plan de suscripción.
class OwnerRegistrationSection extends StatelessWidget {
  const OwnerRegistrationSection({
    super.key,
    required this.personType,
    required this.onPersonTypeChanged,
    required this.nitController,
    required this.companyController,
    required this.plans,
    required this.loadingPlans,
    required this.plansError,
    required this.selectedPlanId,
    required this.onPlanSelected,
    required this.onRetryPlans,
    this.planValidationError,
  });

  final PersonType personType;
  final ValueChanged<PersonType> onPersonTypeChanged;
  final TextEditingController nitController;
  final TextEditingController companyController;
  final List<SubscriptionPlanOption> plans;
  final bool loadingPlans;
  final String? plansError;
  final int? selectedPlanId;
  final ValueChanged<int> onPlanSelected;
  final VoidCallback onRetryPlans;
  final String? planValidationError;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Tipo de persona', style: theme.textTheme.bodyLarge),
        const SizedBox(height: AppSpacing.s2),
        Wrap(
          spacing: AppSpacing.s2,
          runSpacing: AppSpacing.s2,
          children: [
            for (final type in PersonType.values)
              ChoiceChip(
                key: ValueKey('person-type-${type.metadataValue}'),
                label: Text(type.label),
                selected: personType == type,
                showCheckmark: true,
                materialTapTargetSize: MaterialTapTargetSize.padded,
                onSelected: (_) => onPersonTypeChanged(type),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.s4),
        AppTextField(
          label: 'NIT',
          hint: personType == PersonType.juridica
              ? '900123456-8'
              : '1020304050-8',
          controller: nitController,
          keyboardType: TextInputType.text,
          textInputAction: TextInputAction.next,
          validator: AuthValidators.nit(personType),
          autovalidateMode: AutovalidateMode.onUserInteraction,
        ),
        if (personType == PersonType.juridica) ...[
          const SizedBox(height: AppSpacing.s4),
          AppTextField(
            label: 'Razón social',
            hint: 'Nombre de la empresa',
            controller: companyController,
            textInputAction: TextInputAction.next,
            validator: AuthValidators.companyName,
            autovalidateMode: AutovalidateMode.onUserInteraction,
          ),
        ],
        const SizedBox(height: AppSpacing.s4),
        PlanSelector(
          plans: plans,
          loading: loadingPlans,
          errorMessage: plansError,
          selectedPlanId: selectedPlanId,
          onSelected: onPlanSelected,
          onRetry: onRetryPlans,
          validationError: planValidationError,
        ),
      ],
    );
  }
}
