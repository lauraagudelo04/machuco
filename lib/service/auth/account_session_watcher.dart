import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';
import 'package:machuco/database/repository/auth/user_profile_repository.dart';
import 'package:machuco/models/auth/account_status.dart';

/// Motivo por el que [AccountSessionWatcher] terminó la sesión.
enum AccountSessionEnd {
  /// La cuenta se eliminó o se anonimizó desde otro dispositivo.
  accountDeleted,

  /// La sesión dejó de ser válida, p. ej. al cambiar la contraseña en otro
  /// dispositivo. La cuenta sigue existiendo.
  sessionExpired,
}

/// Detecta, con la app abierta, que la cuenta ya no es válida (DA-17): revisa
/// al volver a primer plano y cada [interval] mientras está en primer plano.
///
/// Solo actúa ante una respuesta clara del backend. Sin red o con errores de
/// lectura conserva la sesión, y un usuario sin perfil no se considera
/// eliminado: es el caso normal de "Completar perfil".
class AccountSessionWatcher with WidgetsBindingObserver {
  AccountSessionWatcher({
    required this._auth,
    required this._profiles,
    required this._clearLocalData,
    required this._onSessionEnded,
    this.interval = const Duration(minutes: 15),
  });

  static const _deletedCodes = {'user-not-found'};
  static const _expiredCodes = {'user-token-expired', 'invalid-user-token'};

  final FirebaseAuth _auth;
  final UserProfileRepository _profiles;
  final Future<void> Function(AccountSessionEnd reason) _clearLocalData;
  final void Function(AccountSessionEnd reason) _onSessionEnded;
  final Duration interval;

  Timer? _timer;
  bool _checking = false;

  void start() {
    WidgetsBinding.instance.addObserver(this);
    _startTimer();
  }

  void stop() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _timer = null;
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) => check());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startTimer();
      check();
    } else if (state == AppLifecycleState.paused) {
      _timer?.cancel();
      _timer = null;
    }
  }

  /// Revisa la cuenta actual. Las revisiones no se solapan.
  @visibleForTesting
  Future<void> check() async {
    if (_checking) return;
    final user = _auth.currentUser;
    if (user == null) return;
    _checking = true;
    try {
      final reason = await _findEndReason(user);
      // La sesión pudo cambiar mientras se esperaba la respuesta.
      if (reason == null || _auth.currentUser?.uid != user.uid) return;
      await _endSession(reason);
    } finally {
      _checking = false;
    }
  }

  Future<AccountSessionEnd?> _findEndReason(User user) async {
    try {
      await user.reload();
    } on FirebaseAuthException catch (e) {
      if (_deletedCodes.contains(e.code)) {
        return AccountSessionEnd.accountDeleted;
      }
      if (_expiredCodes.contains(e.code)) {
        return AccountSessionEnd.sessionExpired;
      }
      debugPrint('No se pudo revisar la sesión: ${e.code}');
      return null;
    }
    try {
      // Un administrador eliminado por otro conserva su usuario de Auth, pero
      // su perfil queda anonimizado.
      final profile = await _profiles.getProfile(user.uid);
      return profile?.accountStatus == AccountStatus.anonymized
          ? AccountSessionEnd.accountDeleted
          : null;
    } on UserProfileRepositoryException catch (e) {
      debugPrint('No se pudo revisar el perfil: ${e.type}');
      return null;
    }
  }

  Future<void> _endSession(AccountSessionEnd reason) async {
    try {
      await _auth.signOut();
    } on FirebaseAuthException catch (e) {
      debugPrint('No se pudo cerrar la sesión: ${e.code}');
    }
    try {
      await _clearLocalData(reason);
    } catch (error) {
      debugPrint('No se pudieron borrar los datos locales: $error');
    }
    _onSessionEnded(reason);
  }
}
