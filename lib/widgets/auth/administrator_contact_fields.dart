import 'package:flutter/material.dart';
import 'package:machuco/controllers/auth/login_controller.dart';
import 'package:machuco/controllers/auth/validators/auth_validators.dart';
import 'package:machuco/core/design_system/design_system.dart';
import 'package:machuco/widgets/form/app_phone_field.dart';

/// Nombres, apellidos y celular con indicativo: los mismos componentes y
/// validadores del registro. [catalog] solo aporta los indicativos.
class AdministratorContactFields extends StatelessWidget {
  const AdministratorContactFields({
    super.key,
    required this.catalog,
    required this.firstNames,
    required this.lastNames,
    required this.phone,
    this.enabled = true,
  });

  final LoginController catalog;
  final TextEditingController firstNames;
  final TextEditingController lastNames;
  final TextEditingController phone;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppTextField(
          label: 'Nombres',
          hint: 'Ej. Carlos Andrés',
          controller: firstNames,
          enabled: enabled,
          keyboardType: TextInputType.name,
          textInputAction: TextInputAction.next,
          validator: AuthValidators.firstNames,
          autovalidateMode: AutovalidateMode.onUserInteraction,
        ),
        const SizedBox(height: AppSpacing.s4),
        AppTextField(
          label: 'Apellidos',
          hint: 'Ej. Rodríguez Pérez',
          controller: lastNames,
          enabled: enabled,
          keyboardType: TextInputType.name,
          textInputAction: TextInputAction.next,
          validator: AuthValidators.lastNames,
          autovalidateMode: AutovalidateMode.onUserInteraction,
        ),
        const SizedBox(height: AppSpacing.s4),
        Text('Número de celular', style: theme.textTheme.bodyLarge),
        const SizedBox(height: AppSpacing.s2),
        AppPhoneField(
          countryCodes: catalog.countryPhoneCodes,
          selectedCountryCode: catalog.selectedCountryPhoneCode,
          onCountryCodeSelected: catalog.selectCountryPhoneCode,
          phoneController: phone,
          loading: catalog.isLoadingCountryPhoneCodes,
          errorMessage: catalog.countryPhoneCodesError,
          onRetry: () => catalog.loadCountryPhoneCodes(forceRefresh: true),
          validator: catalog.validatePhoneNumber,
        ),
      ],
    );
  }
}
