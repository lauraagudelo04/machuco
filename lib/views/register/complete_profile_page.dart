import 'package:flutter/material.dart';
import 'package:machuco/controllers/auth/login_controller.dart';
import 'package:machuco/controllers/auth/validators/auth_validators.dart';
import 'package:machuco/core/design_system/design_system.dart';
import 'package:machuco/models/auth/person_type.dart';
import 'package:machuco/models/auth/registered_user.dart';
import 'package:machuco/models/auth/social_auth_result.dart';
import 'package:machuco/models/auth/social_profile_data.dart';
import 'package:machuco/service/auth/auth_service.dart';
import 'package:machuco/service/auth/firebase_social_auth_service.dart';
import 'package:machuco/views/login/auth_controller_factory.dart';
import 'package:machuco/views/login/logout_navigation.dart';
import 'package:machuco/views/login/social_auth_flow.dart';
import 'package:machuco/views/register/profile_fields.dart';
import 'package:machuco/widgets/auth/auth_header.dart';
import 'package:machuco/widgets/auth/auth_notice.dart';
import 'package:machuco/widgets/auth/terms_sheet.dart';

/// Argumentos de la ruta `AuthRoutes.completeProfile`.
class CompleteProfileArgs {
  const CompleteProfileArgs({
    required this.profile,
    required this.social,
    this.controller,
    this.loginBuilder,
  });

  final SocialAuthIncompleteProfile profile;
  final SocialAuthService social;

  /// Para pruebas; si es `null` se crea el de producción.
  final LoginController? controller;

  /// Pantalla a la que vuelve al cancelar; por defecto el login. Para pruebas.
  final WidgetBuilder? loginBuilder;
}

/// "Completar perfil" tras el primer ingreso con Google o GitHub: rol, datos
/// obligatorios por rol y términos. El correo es el del proveedor y no se
/// edita; no hay contraseña. "Cancelar" cierra la sesión y borra el usuario de
/// Firebase que aún no tiene perfil (D10): no queda ninguna cuenta a medias.
class CompleteProfilePage extends StatefulWidget {
  const CompleteProfilePage({super.key, required this.args});

  final CompleteProfileArgs args;

  @override
  State<CompleteProfilePage> createState() => _CompleteProfilePageState();
}

class _CompleteProfilePageState extends State<CompleteProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _firstNames = TextEditingController();
  final _lastNames = TextEditingController();
  final _phone = TextEditingController();
  final _birthDate = TextEditingController();
  final _nit = TextEditingController();
  final _company = TextEditingController();
  late final TextEditingController _email;

  late final LoginController _controller;
  late final bool _ownsController;
  RegisteredUserRole _role = RegisteredUserRole.client;
  PersonType _personType = PersonType.natural;
  int? _planId;
  String? _planError;
  bool _submitting = false;
  bool _leaving = false;
  AuthFailure? _failure;

  SocialAuthIncompleteProfile get _profile => widget.args.profile;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.args.controller == null;
    _controller = widget.args.controller ?? buildLoginController();
    _email = TextEditingController(text: _profile.email);
    _prefillNames(_profile.displayName);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (_controller.countryPhoneCodes.isEmpty &&
          !_controller.isLoadingCountryPhoneCodes) {
        await _controller.loadCountryPhoneCodes();
      }
      if (mounted) _prefillPhone(_profile.phoneNumber);
    });
  }

  /// Si el proveedor entregó un celular E.164, elige el indicativo del
  /// catálogo que coincide (el más largo, p. ej. `+593` antes que `+5`) y
  /// deja el resto en "Celular". Si no coincide con ningún país, no precarga.
  void _prefillPhone(String? phoneNumber) {
    if (phoneNumber == null || _phone.text.isNotEmpty) return;
    final digits = phoneNumber.replaceAll(RegExp(r'\D'), '');
    if (!phoneNumber.trim().startsWith('+') || digits.isEmpty) return;
    final matches =
        _controller.countryPhoneCodes
            .where(
              (code) => digits.startsWith(
                code.dialCode.replaceAll(RegExp(r'\D'), ''),
              ),
            )
            .toList()
          ..sort((a, b) => b.dialCode.length.compareTo(a.dialCode.length));
    if (matches.isEmpty) return;
    final code = matches.first;
    final local = digits.substring(
      code.dialCode.replaceAll(RegExp(r'\D'), '').length,
    );
    if (local.isEmpty) return;
    _controller.selectCountryPhoneCode(code);
    _phone.text = local;
  }

  /// Primer nombre a "Nombres" y el resto a "Apellidos"; ambos editables.
  void _prefillNames(String? displayName) {
    final parts = (displayName ?? '').trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return;
    _firstNames.text = parts.first;
    _lastNames.text = parts.skip(1).join(' ');
  }

  @override
  void dispose() {
    for (final c in [
      _firstNames,
      _lastNames,
      _phone,
      _birthDate,
      _nit,
      _company,
      _email,
    ]) {
      c.dispose();
    }
    if (_ownsController) _controller.dispose();
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

  void _selectPersonType(PersonType type) => setState(() {
    _personType = type;
    if (type == PersonType.natural) _company.clear();
  });

  Future<void> _submit() async {
    if (_submitting || _leaving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final code = _controller.selectedCountryPhoneCode;
    if (code == null) return;
    final isOwner = _role == RegisteredUserRole.owner;
    if (isOwner && _planId == null) {
      setState(() => _planError = 'Selecciona un plan.');
      return;
    }
    // Igual que el registro con correo: se guarda con el indicativo.
    final phone =
        '${code.dialCode}${_phone.text.replaceAll(RegExp(r'\D'), '')}';
    final data = isOwner
        ? SocialProfileData.owner(
            firstNames: _firstNames.text,
            lastNames: _lastNames.text,
            phoneCountryCodeId: code.id,
            phoneNumber: phone,
            personType: _personType,
            nit: _nit.text,
            companyName: _company.text,
            planId: _planId!,
          )
        : SocialProfileData.client(
            firstNames: _firstNames.text,
            lastNames: _lastNames.text,
            phoneCountryCodeId: code.id,
            phoneNumber: phone,
            birthDate: AuthValidators.parseBirthDate(_birthDate.text)!,
          );

    setState(() {
      _submitting = true;
      _failure = null;
    });
    final result = await widget.args.social.completeProfile(data);
    if (!mounted) return;
    final failure = await routeSocialResult(
      context,
      result: result,
      controller: _controller,
      social: widget.args.social,
    );
    if (!mounted) return;
    setState(() {
      _submitting = false;
      _failure = failure;
    });
  }

  Future<void> _cancel() async {
    // "Atrás" también llega aquí: mientras se guarda el perfil no se abandona,
    // porque abandonar puede borrar el usuario que se está registrando.
    if (_leaving || _submitting) return;
    setState(() => _leaving = true);
    await widget.args.social.abandonProfileCompletion();
    if (!mounted) return;
    const notice = 'Cancelaste el registro. Puedes registrarte cuando quieras.';
    final builder = widget.args.loginBuilder;
    if (builder == null) {
      goToLogin(context, notice: notice);
      return;
    }
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: builder),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final providerName = _profile.provider.displayName;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _cancel();
      },
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.screen),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: ListenableBuilder(
                  listenable: _controller,
                  builder: (context, _) => Form(
                    key: _formKey,
                    child: Column(
                      key: const ValueKey('complete-profile-form'),
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const AuthHeader(
                          title: 'Completa tu perfil',
                          subtitle: 'Solo falta un paso para usar Machuco',
                        ),
                        const SizedBox(height: AppSpacing.s4),
                        AuthNotice(
                          tone: AuthNoticeTone.info,
                          icon: Icons.verified_user_outlined,
                          message:
                              'Ingresaste con $providerName. Completa tus '
                              'datos para crear tu cuenta.',
                        ),
                        const SizedBox(height: AppSpacing.s4),
                        AppTextField(
                          label: 'Correo electrónico',
                          controller: _email,
                          enabled: false,
                        ),
                        const SizedBox(height: AppSpacing.s4),
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
                        if (_failure case final failure?) ...[
                          const SizedBox(height: AppSpacing.s4),
                          AuthNotice(
                            message: failure.message,
                            icon: failure.type == AuthFailureType.network
                                ? Icons.wifi_off_outlined
                                : Icons.error_outline,
                            actionLabel: failure.type == AuthFailureType.network
                                ? 'Reintentar'
                                : null,
                            onAction: failure.type == AuthFailureType.network
                                ? _submit
                                : null,
                          ),
                        ],
                        const SizedBox(height: AppSpacing.s2),
                        const Center(child: TermsLink()),
                        const SizedBox(height: AppSpacing.s2),
                        AppButton(
                          key: const ValueKey('complete-profile-submit'),
                          label: 'Guardar y continuar',
                          loading: _submitting,
                          onPressed: _canSubmit ? _submit : null,
                        ),
                        const SizedBox(height: AppSpacing.s3),
                        AppButton(
                          key: const ValueKey('complete-profile-cancel'),
                          label: 'Cancelar',
                          variant: AppButtonVariant.secondary,
                          loading: _leaving,
                          onPressed: _submitting ? null : _cancel,
                        ),
                        const SizedBox(height: AppSpacing.s2),
                        Text(
                          'Si cancelas, no se creará tu cuenta y cerraremos tu '
                          'sesión. Podrás registrarte de nuevo con '
                          '$providerName cuando quieras.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: context.appColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  bool get _canSubmit {
    if (_leaving || _controller.selectedCountryPhoneCode == null) return false;
    if (_role != RegisteredUserRole.owner) return true;
    return !_controller.isLoadingSubscriptionPlans &&
        _controller.subscriptionPlansError == null &&
        _controller.subscriptionPlans.isNotEmpty;
  }
}
