import 'package:flutter/material.dart';
import 'package:machuco/controllers/auth/login_controller.dart';
import 'package:machuco/controllers/auth/validators/auth_validators.dart';
import 'package:machuco/core/design_system/design_system.dart';
import 'package:machuco/models/auth/person_type.dart';
import 'package:machuco/models/auth/registered_user.dart';
import 'package:machuco/models/auth/registration_data.dart';
import 'package:machuco/views/register/profile_fields.dart';
import 'package:machuco/widgets/auth/auth_password_field.dart';
import 'package:machuco/widgets/auth/terms_sheet.dart';

/// Registro por rol en una sola pantalla con scroll (sin stepper).
///
/// Los datos comunes viven en este estado y se conservan al cambiar de rol;
/// solo el bloque propio del rol aparece o desaparece. Valida con
/// [AuthValidators] y entrega un [RegistrationData] a [onSubmit]; quien lo
/// usa decide qué hacer con el resultado o con el `AuthFailure`.
class RegisterForm extends StatefulWidget {
  const RegisterForm({
    super.key,
    required this.controller,
    required this.onSubmit,
    required this.onLoginTap,
    this.socialButtons,
  });

  final LoginController controller;

  /// "Continuar con Google/GitHub" (los arma la página que conoce el flujo).
  final Widget? socialButtons;
  final Future<void> Function(RegistrationData data) onSubmit;
  final VoidCallback onLoginTap;

  @override
  State<RegisterForm> createState() => _RegisterFormState();
}

class _RegisterFormState extends State<RegisterForm> {
  final _formKey = GlobalKey<FormState>();
  final _firstNames = TextEditingController();
  final _lastNames = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _birthDate = TextEditingController();
  final _nit = TextEditingController();
  final _company = TextEditingController();

  RegisteredUserRole _role = RegisteredUserRole.client;
  PersonType _personType = PersonType.natural;
  int? _planId;
  String? _planError;

  LoginController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_controller.countryPhoneCodes.isEmpty &&
          !_controller.isLoadingCountryPhoneCodes) {
        _controller.loadCountryPhoneCodes();
      }
    });
  }

  @override
  void dispose() {
    for (final c in [
      _firstNames,
      _lastNames,
      _phone,
      _email,
      _password,
      _confirm,
      _birthDate,
      _nit,
      _company,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _selectRole(RegisteredUserRole role) {
    setState(() {
      _role = role;
      _planError = null;
    });
    if (role == RegisteredUserRole.owner &&
        _controller.subscriptionPlans.isEmpty &&
        !_controller.isLoadingSubscriptionPlans) {
      _controller.loadSubscriptionPlans();
    }
  }

  void _selectPersonType(PersonType type) {
    setState(() {
      _personType = type;
      // Se conserva el NIT; la razón social solo aplica a persona jurídica.
      if (type == PersonType.natural) _company.clear();
    });
  }

  bool get _plansAvailable =>
      !_controller.isLoadingSubscriptionPlans &&
      _controller.subscriptionPlansError == null &&
      _controller.subscriptionPlans.isNotEmpty;

  Future<void> _submit() async {
    if (_controller.isSubmitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final code = _controller.selectedCountryPhoneCode;
    if (code == null) return;
    final isOwner = _role == RegisteredUserRole.owner;
    if (isOwner && _planId == null) {
      setState(() => _planError = 'Selecciona un plan.');
      return;
    }
    final phone = _phone.text.replaceAll(RegExp(r'\s'), '');
    final data = isOwner
        ? RegistrationData.owner(
            firstNames: _firstNames.text,
            lastNames: _lastNames.text,
            phoneCountryCodeId: code.id,
            phoneNumber: phone,
            email: _email.text,
            password: _password.text,
            personType: _personType,
            nit: _nit.text,
            companyName: _company.text,
            planId: _planId!,
          )
        : RegistrationData.client(
            firstNames: _firstNames.text,
            lastNames: _lastNames.text,
            phoneCountryCodeId: code.id,
            phoneNumber: phone,
            email: _email.text,
            password: _password.text,
            birthDate: AuthValidators.parseBirthDate(_birthDate.text)!,
          );
    await widget.onSubmit(data);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final isOwner = _role == RegisteredUserRole.owner;
        final canSubmit =
            _controller.selectedCountryPhoneCode != null &&
            (!isOwner || _plansAvailable);
        return Form(
          key: _formKey,
          child: AutofillGroup(
            key: const ValueKey('register-form'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ProfileFields(
                  controller: _controller,
                  role: _role,
                  onRoleSelected: _selectRole,
                  firstNames: _firstNames,
                  lastNames: _lastNames,
                  phone: _phone,
                  birthDate: _birthDate,
                  nit: _nit,
                  company: _company,
                  personType: _personType,
                  onPersonTypeChanged: _selectPersonType,
                  planId: _planId,
                  planError: _planError,
                  onPlanSelected: (id) => setState(() {
                    _planId = id;
                    _planError = null;
                  }),
                ),
                const SizedBox(height: AppSpacing.s4),
                AppTextField(
                  label: 'Correo electrónico',
                  hint: 'correo@ejemplo.com',
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
                  validator: AuthValidators.email,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                ),
                const SizedBox(height: AppSpacing.s4),
                AuthPasswordField(
                  controller: _password,
                  hint: 'Mínimo ${AuthValidators.passwordMinLength} caracteres',
                  autofillHints: const [AutofillHints.newPassword],
                  validator: AuthValidators.password,
                ),
                const SizedBox(height: AppSpacing.s4),
                AuthPasswordField(
                  controller: _confirm,
                  label: 'Confirmar contraseña',
                  hint: 'Repite tu contraseña',
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.newPassword],
                  validator: AuthValidators.confirmPassword(
                    () => _password.text,
                  ),
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: AppSpacing.s2),
                const Center(child: TermsLink()),
                const SizedBox(height: AppSpacing.s2),
                AppButton(
                  label: 'Crear cuenta',
                  loading: _controller.isSubmitting,
                  onPressed: canSubmit ? _submit : null,
                ),
                const SizedBox(height: AppSpacing.s4),
                ?widget.socialButtons,
                Text.rich(
                  TextSpan(
                    text: '¿Ya tienes cuenta? ',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: context.appColors.textSecondary,
                    ),
                    children: [
                      WidgetSpan(
                        alignment: PlaceholderAlignment.middle,
                        child: InkWell(
                          onTap: widget.onLoginTap,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 48),
                            child: Center(
                              widthFactor: 1,
                              child: Text(
                                'Inicia sesión',
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
