import 'package:flutter/material.dart';
import 'package:machuco/controllers/auth/login_controller.dart';
import 'package:machuco/core/design_system/design_system.dart';
import 'package:machuco/service/auth/firebase_social_auth_service.dart';
import 'package:machuco/views/login/auth_controller_factory.dart';
import 'package:machuco/views/login/logout_navigation.dart';
import 'package:machuco/views/login/social_auth_flow.dart';
import 'package:machuco/widgets/auth/delete_account_sheet.dart';

/// Acción de peligro "Eliminar cuenta" que cada perfil agrega al final
/// (DA-13). Abre [showDeleteAccountSheet] y, si la cuenta se eliminó, lleva al
/// login limpiando la pila.
///
/// Si no se inyecta [controller] (o [socialAuthService]) se construyen de
/// forma perezosa al tocar el botón, así las vistas no abren Firebase al
/// pintarse. Un [controller] inyectado lo cierra quien lo creó.
class DeleteAccountAction extends StatefulWidget {
  const DeleteAccountAction({
    super.key,
    this.controller,
    this.socialAuthService,
    this.isAdministrator = false,
  });

  final LoginController? controller;
  final SocialAuthService? socialAuthService;
  final bool isAdministrator;

  @override
  State<DeleteAccountAction> createState() => _DeleteAccountActionState();
}

class _DeleteAccountActionState extends State<DeleteAccountAction> {
  LoginController? _ownedController;

  @override
  void dispose() {
    _ownedController?.dispose();
    super.dispose();
  }

  Future<void> _onPressed() async {
    final controller =
        widget.controller ?? (_ownedController ??= buildLoginController());
    final social = widget.socialAuthService ?? buildSocialAuthService();
    final deleted = await showDeleteAccountSheet(
      context,
      controller: controller,
      socialAuthService: social,
      isAdministrator: widget.isAdministrator,
    );
    if (!deleted || !mounted) return;
    goToLogin(context, notice: 'Tu cuenta fue eliminada');
  }

  @override
  Widget build(BuildContext context) {
    return AppButton(
      key: const ValueKey('delete-account-action'),
      label: 'Eliminar cuenta',
      icon: Icons.delete_outline,
      variant: AppButtonVariant.destructive,
      size: AppButtonSize.medium,
      onPressed: _onPressed,
    );
  }
}
