import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:machuco/database/repository/auth/auth_user_profile_repository.dart';
import 'package:machuco/database/repository/auth/user_profile_repository.dart';
import 'package:machuco/service/auth/account_session_watcher.dart';
import 'package:machuco/service/auth/auth_preferences.dart';
import 'package:machuco/views/login/login_page.dart';

AccountSessionWatcher? _watcher;
NavigatorState? _navigator;

/// Arranca una sola vez el [AccountSessionWatcher] de producción. Lo llama el
/// login, que siempre es la primera pantalla; el vigilante sigue activo
/// después de que el login sale de la pila. Sin Firebase (pruebas de widgets)
/// no hace nada.
void ensureAccountSessionWatcher(BuildContext context) {
  _navigator = Navigator.maybeOf(context, rootNavigator: true);
  if (_watcher != null) return;
  try {
    _watcher = AccountSessionWatcher(
      auth: FirebaseAuth.instance,
      profiles: FirestoreUserProfileRepository(),
      clearLocalData: _clearLocalData,
      onSessionEnded: _goToLogin,
    )..start();
  } catch (error) {
    debugPrint('Vigilancia de la sesión no disponible: $error');
  }
}

/// Una cuenta eliminada borra todo el namespace `auth`; una sesión vencida
/// conserva el correo recordado, igual que cerrar sesión.
Future<void> _clearLocalData(AccountSessionEnd reason) async {
  final preferences = AuthPreferences();
  await switch (reason) {
    AccountSessionEnd.accountDeleted => preferences.clearAll(),
    AccountSessionEnd.sessionExpired => preferences.clearCurrentUserEmail(),
  };
  await FloorAuthUserProfileRepository().clear();
}

void _goToLogin(AccountSessionEnd reason) {
  final navigator = _navigator;
  if (navigator == null || !navigator.mounted) return;
  final notice = switch (reason) {
    AccountSessionEnd.accountDeleted => 'Tu cuenta fue eliminada.',
    AccountSessionEnd.sessionExpired =>
      'Tu sesión expiró. Inicia sesión de nuevo.',
  };
  navigator.pushAndRemoveUntil(
    MaterialPageRoute<void>(builder: (_) => LoginPage(notice: notice)),
    (_) => false,
  );
}
