import 'package:flutter/material.dart';
import 'package:machuco/service/auth/auth0_auth_service.dart';
import 'package:machuco/views/login/login_page.dart';

Future<void> logoutAndGoToLogin(
  BuildContext context, {
  AuthService? authService,
}) async {
  final service = authService ?? Auth0AuthService.fromEnvironment();
  if (service != null) {
    await service.logout();
  }
  if (!context.mounted) {
    return;
  }
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute<void>(builder: (_) => const LoginPage()),
    (_) => false,
  );
}
