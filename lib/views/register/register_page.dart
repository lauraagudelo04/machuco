import 'package:flutter/material.dart';
import 'package:machuco/views/login/login_page.dart';

class RegisterPage extends StatelessWidget {
  const RegisterPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const LoginPage(initialTab: AuthTab.register);
  }
}
