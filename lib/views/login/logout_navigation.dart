import 'package:flutter/material.dart';
import 'package:machuco/service/auth/auth_service.dart';
import 'package:machuco/service/auth/firebase_auth_service.dart';
import 'package:machuco/views/login/login_page.dart';

Future<void> logoutAndGoToLogin(
  BuildContext context, {
  AuthService? authService,
}) async {
  final service = authService ?? FirebaseAuthService();
  await service.logout();
  if (!context.mounted) {
    return;
  }
  goToLogin(context);
}

/// Lleva al login limpiando la pila. [notice] se muestra como aviso breve
/// (p. ej. "Tu cuenta fue eliminada").
void goToLogin(BuildContext context, {String? notice}) {
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute<void>(builder: (_) => LoginPage(notice: notice)),
    (_) => false,
  );
}
