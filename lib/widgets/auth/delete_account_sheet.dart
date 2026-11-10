import 'package:flutter/material.dart';
import 'package:machuco/controllers/auth/login_controller.dart';
import 'package:machuco/core/design_system/design_system.dart';
import 'package:machuco/models/auth/auth_provider_kind.dart';
import 'package:machuco/service/auth/auth_service.dart';
import 'package:machuco/service/auth/firebase_social_auth_service.dart';
import 'package:machuco/widgets/auth/auth_notice.dart';
import 'package:machuco/widgets/auth/auth_password_field.dart';
import 'package:machuco/widgets/form/app_bottom_sheet.dart';

/// Abre la hoja "Eliminar cuenta". Devuelve `true` si la cuenta se eliminó;
/// entonces quien llama debe navegar al login limpiando la pila.
///
/// Si la cuenta solo tiene Google o GitHub, [socialAuthService] confirma con
/// ese proveedor en lugar de pedir una contraseña. Sin él (o si la cuenta
/// tiene contraseña) se usa el flujo con contraseña de [controller].
Future<bool> showDeleteAccountSheet(
  BuildContext context, {
  required LoginController controller,
  SocialAuthService? socialAuthService,
  bool isAdministrator = false,
}) async {
  final deleted = await AppBottomSheet.show<bool>(
    context,
    title: 'Eliminar cuenta',
    builder: (_) => DeleteAccountSheet(
      controller: controller,
      socialAuthService: socialAuthService,
      isAdministrator: isAdministrator,
    ),
  );
  return deleted ?? false;
}

/// Contenido de la hoja de eliminación de cuenta (acción irreversible).
class DeleteAccountSheet extends StatefulWidget {
  const DeleteAccountSheet({
    super.key,
    required this.controller,
    this.socialAuthService,
    this.isAdministrator = false,
  });

  final LoginController controller;
  final SocialAuthService? socialAuthService;

  /// Un administrador no borra su registro: se anonimiza.
  final bool isAdministrator;

  @override
  State<DeleteAccountSheet> createState() => _DeleteAccountSheetState();
}

class _DeleteAccountSheetState extends State<DeleteAccountSheet> {
  /// Proveedor social con el que se confirma, o `null` si se usa contraseña.
  late final AuthProviderKind? _socialProvider = _resolveSocialProvider();

  AuthProviderKind? _resolveSocialProvider() {
    final linked = widget.socialAuthService?.linkedProviders ?? const [];
    if (linked.isEmpty || linked.contains(AuthProviderKind.password)) {
      return null;
    }
    return linked.firstWhere(
      (kind) => kind.isSocial,
      orElse: () => AuthProviderKind.google,
    );
  }

  List<String> get _consequences => [
    widget.isAdministrator
        ? 'Tu nombre, correo y celular (tu cuenta quedará anonimizada).'
        : 'Tu perfil y tus datos personales.',
    _socialProvider == null
        ? 'El acceso con tu correo y contraseña.'
        : 'El acceso con ${_socialProvider.displayName}.',
    'Los datos guardados en este dispositivo.',
  ];

  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _submitting = false;
  String? _errorMessage;

  bool get _canSubmit =>
      (_socialProvider != null || _passwordController.text.isNotEmpty) &&
      _confirmController.text.trim() == LoginController.deleteConfirmationText;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_canSubmit || _submitting) return;
    setState(() {
      _submitting = true;
      _errorMessage = null;
    });
    try {
      final social = widget.socialAuthService;
      if (_socialProvider != null && social != null) {
        // Reautentica con el proveedor, borra perfil y usuario; luego el
        // controller limpia la sesión y el correo guardados en el dispositivo.
        await social.deleteAccount();
        await widget.controller.logout();
      } else {
        await widget.controller.deleteAccount(
          password: _passwordController.text,
          confirmationText: _confirmController.text,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on AuthFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _errorMessage = failure.type == AuthFailureType.lastAdministrator
            ? 'Eres el único administrador activo. Crea otro administrador '
                  'antes de eliminar tu cuenta.'
            : failure.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.isAdministrator
              ? 'Esta acción es definitiva y no se puede deshacer. Se '
                    'anonimizará tu cuenta de administrador:'
              : 'Esta acción es definitiva y no se puede deshacer. Se '
                    'eliminará:',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: context.appColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.s2),
        for (final item in _consequences)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.s1),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.remove_circle_outline,
                  size: AppSpacing.s4,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(width: AppSpacing.s2),
                Expanded(child: Text(item, style: theme.textTheme.bodyMedium)),
              ],
            ),
          ),
        const SizedBox(height: AppSpacing.s3),
        if (_socialProvider case final provider?)
          Text(
            'Para confirmar que eres tú, te pediremos ingresar de nuevo con '
            '${provider.displayName}.',
            style: theme.textTheme.bodyMedium,
          )
        else
          AuthPasswordField(
            controller: _passwordController,
            label: 'Contraseña actual',
            autofillHints: const [AutofillHints.password],
            enabled: !_submitting,
            onChanged: (_) => setState(() {}),
          ),
        const SizedBox(height: AppSpacing.s3),
        AppTextField(
          label:
              'Escribe ${LoginController.deleteConfirmationText} para confirmar',
          controller: _confirmController,
          enabled: !_submitting,
          textInputAction: TextInputAction.done,
          onChanged: (_) => setState(() {}),
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: AppSpacing.s3),
          AuthNotice(message: _errorMessage!),
        ],
        const SizedBox(height: AppSpacing.s4),
        AppButton(
          key: const ValueKey('delete-account-submit'),
          label: _socialProvider == null
              ? 'Eliminar definitivamente'
              : 'Confirmar con ${_socialProvider.displayName} y eliminar',
          variant: AppButtonVariant.destructive,
          loading: _submitting,
          onPressed: _canSubmit ? _submit : null,
        ),
        const SizedBox(height: AppSpacing.s2),
        AppButton(
          label: 'Cancelar',
          variant: AppButtonVariant.secondary,
          onPressed: _submitting
              ? null
              : () => Navigator.of(context).pop(false),
        ),
      ],
    );
  }
}
