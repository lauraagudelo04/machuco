import 'package:flutter/material.dart';
import 'package:machuco/controllers/auth/administrators_controller.dart';
import 'package:machuco/controllers/auth/login_controller.dart';
import 'package:machuco/controllers/auth/validators/auth_validators.dart';
import 'package:machuco/core/design_system/design_system.dart';
import 'package:machuco/database/repository/auth/administrators_repository.dart';
import 'package:machuco/views/login/auth_controller_factory.dart';
import 'package:machuco/widgets/auth/administrator_contact_fields.dart';
import 'package:machuco/widgets/auth/auth_notice.dart';
import 'package:machuco/widgets/auth/temporary_password_dialog.dart';
import 'package:machuco/widgets/layout/responsive_content.dart';

/// Formulario "Crear administrador": sin contraseña ni documento. Al crear
/// muestra la contraseña temporal una sola vez. Hace `pop(true)` al terminar.
class CreateAdminPage extends StatefulWidget {
  const CreateAdminPage({super.key, required this.controller, this.catalog});

  final AdministratorsController controller;

  /// Solo aporta los indicativos. Si es `null` se crea el de producción.
  final LoginController? catalog;

  @override
  State<CreateAdminPage> createState() => _CreateAdminPageState();
}

class _CreateAdminPageState extends State<CreateAdminPage> {
  final _formKey = GlobalKey<FormState>();
  final _firstNames = TextEditingController();
  final _lastNames = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();

  late final LoginController _catalog;
  late final bool _ownsCatalog;
  String? _emailInUse;

  AdministratorsController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _ownsCatalog = widget.catalog == null;
    _catalog = widget.catalog ?? buildLoginController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _controller.clearError();
      if (_catalog.countryPhoneCodes.isEmpty &&
          !_catalog.isLoadingCountryPhoneCodes) {
        _catalog.loadCountryPhoneCodes();
      }
    });
  }

  @override
  void dispose() {
    for (final c in [_firstNames, _lastNames, _phone, _email]) {
      c.dispose();
    }
    if (_ownsCatalog) _catalog.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_controller.isSubmitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final code = _catalog.selectedCountryPhoneCode;
    if (code == null) return;
    setState(() => _emailInUse = null);
    final created = await _controller.create(
      firstNames: _firstNames.text,
      lastNames: _lastNames.text,
      phoneCode: code,
      phoneNumber: _phone.text,
      email: _email.text,
    );
    if (!mounted) return;
    if (created == null) {
      if (_controller.errorType == AdministratorsFailureType.emailInUse) {
        setState(() => _emailInUse = _controller.error);
      }
      return;
    }
    await showTemporaryPasswordDialog(
      context,
      email: created.profile.email,
      password: created.temporaryPassword,
    );
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  Widget? _buildNotice() {
    final message = _controller.error;
    final type = _controller.errorType;
    if (message == null || type == AdministratorsFailureType.emailInUse) {
      return null;
    }
    final isNetwork = type == AdministratorsFailureType.network;
    return AuthNotice(
      message: message,
      icon: isNetwork ? Icons.wifi_off_outlined : Icons.error_outline,
      actionLabel: isNetwork ? 'Reintentar' : null,
      onAction: isNetwork ? _submit : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Crear administrador')),
      body: SafeArea(
        child: SingleChildScrollView(
          child: ResponsiveContent(
            maxWidth: 560,
            padding: const EdgeInsets.all(AppSpacing.s4),
            child: ListenableBuilder(
              listenable: Listenable.merge([_controller, _catalog]),
              builder: (context, _) {
                final notice = _buildNotice();
                return Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Se creará con una contraseña temporal que verás una '
                        'sola vez. No se envía ningún correo.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: context.appColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.s4),
                      if (notice != null) ...[
                        notice,
                        const SizedBox(height: AppSpacing.s4),
                      ],
                      AdministratorContactFields(
                        catalog: _catalog,
                        firstNames: _firstNames,
                        lastNames: _lastNames,
                        phone: _phone,
                        enabled: !_controller.isSubmitting,
                      ),
                      const SizedBox(height: AppSpacing.s4),
                      AppTextField(
                        label: 'Correo electrónico',
                        hint: 'correo@ejemplo.com',
                        controller: _email,
                        enabled: !_controller.isSubmitting,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.done,
                        validator: AuthValidators.email,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        errorText: _emailInUse,
                        onChanged: (_) {
                          if (_emailInUse != null) {
                            setState(() => _emailInUse = null);
                          }
                        },
                        onSubmitted: (_) => _submit(),
                      ),
                      const SizedBox(height: AppSpacing.s5),
                      AppButton(
                        label: 'Crear',
                        loading: _controller.isSubmitting,
                        onPressed: _catalog.selectedCountryPhoneCode == null
                            ? null
                            : _submit,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
