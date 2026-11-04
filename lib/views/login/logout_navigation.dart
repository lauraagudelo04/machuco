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
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute<void>(builder: (_) => const LoginPage()),
    (_) => false,
  );
}
