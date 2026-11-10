import 'package:flutter/material.dart';
import 'package:machuco/controllers/auth/login_controller.dart';
import 'package:machuco/controllers/auth/validators/auth_validators.dart';
import 'package:machuco/core/design_system/design_system.dart';
import 'package:machuco/models/auth/person_type.dart';
import 'package:machuco/models/auth/registered_user.dart';
import 'package:machuco/views/register/client_registration_section.dart';
import 'package:machuco/views/register/owner_registration_section.dart';
import 'package:machuco/views/register/role_selector.dart';
import 'package:machuco/widgets/form/app_phone_field.dart';

/// Campos de perfil por rol que comparten "Registrarse" y "Completar
/// perfil": tipo de perfil, nombres, apellidos, celular con indicativo y el
/// bloque propio del rol (fecha de nacimiento o datos del propietario).
///
/// No guarda estado: quien lo usa conserva los controladores y la selección,
/// así los datos comunes sobreviven al cambio de rol.
class ProfileFields extends StatelessWidget {
  const ProfileFields({
    super.key,
    required this.controller,
    required this.role,
    required this.onRoleSelected,
    required this.firstNames,
    required this.lastNames,
    required this.phone,
    required this.birthDate,
    required this.nit,
    required this.company,
    required this.personType,
    required this.onPersonTypeChanged,
    required this.planId,
    required this.planError,
    required this.onPlanSelected,
  });

  final LoginController controller;
  final RegisteredUserRole role;
  final ValueChanged<RegisteredUserRole> onRoleSelected;
  final TextEditingController firstNames;
  final TextEditingController lastNames;
  final TextEditingController phone;
  final TextEditingController birthDate;
  final TextEditingController nit;
  final TextEditingController company;
  final PersonType personType;
  final ValueChanged<PersonType> onPersonTypeChanged;
  final int? planId;
  final String? planError;
  final ValueChanged<int> onPlanSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final duration = reduceMotion ? Duration.zero : AppMotion.normal;
    final isOwner = role == RegisteredUserRole.owner;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Tipo de perfil', style: theme.textTheme.bodyLarge),
        const SizedBox(height: AppSpacing.s2),
        RoleSelector(selectedRole: role, onSelected: onRoleSelected),
        const SizedBox(height: AppSpacing.s4),
        AppTextField(
          label: 'Nombres',
          hint: 'Ej. Carlos Andrés',
          controller: firstNames,
          keyboardType: TextInputType.name,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.givenName],
          validator: AuthValidators.firstNames,
          autovalidateMode: AutovalidateMode.onUserInteraction,
        ),
        const SizedBox(height: AppSpacing.s4),
        AppTextField(
          label: 'Apellidos',
          hint: 'Ej. Rodríguez Pérez',
          controller: lastNames,
          keyboardType: TextInputType.name,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.familyName],
          validator: AuthValidators.lastNames,
          autovalidateMode: AutovalidateMode.onUserInteraction,
        ),
        const SizedBox(height: AppSpacing.s4),
        Text('Número de celular', style: theme.textTheme.bodyLarge),
        const SizedBox(height: AppSpacing.s2),
        AppPhoneField(
          countryCodes: controller.countryPhoneCodes,
          selectedCountryCode: controller.selectedCountryPhoneCode,
          onCountryCodeSelected: controller.selectCountryPhoneCode,
          phoneController: phone,
          loading: controller.isLoadingCountryPhoneCodes,
          errorMessage: controller.countryPhoneCodesError,
          onRetry: () => controller.loadCountryPhoneCodes(forceRefresh: true),
          validator: controller.validatePhoneNumber,
        ),
        const SizedBox(height: AppSpacing.s4),
        AnimatedSize(
          duration: duration,
          curve: AppMotion.standard,
          alignment: Alignment.topCenter,
          child: AnimatedSwitcher(
            duration: duration,
            switchInCurve: AppMotion.standard,
            child: AppCard(
              key: ValueKey('role-block-${role.name}'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      isOwner ? 'Datos del propietario' : 'Datos del cliente',
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s3),
                  if (isOwner)
                    OwnerRegistrationSection(
                      personType: personType,
                      onPersonTypeChanged: onPersonTypeChanged,
                      nitController: nit,
                      companyController: company,
                      plans: controller.subscriptionPlans,
                      loadingPlans: controller.isLoadingSubscriptionPlans,
                      plansError: controller.subscriptionPlansError,
                      selectedPlanId: planId,
                      planValidationError: planError,
                      onPlanSelected: onPlanSelected,
                      onRetryPlans: () =>
                          controller.loadSubscriptionPlans(forceRefresh: true),
                    )
                  else
                    ClientRegistrationSection(birthDateController: birthDate),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
