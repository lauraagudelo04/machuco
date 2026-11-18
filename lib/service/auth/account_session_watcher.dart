import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';
import 'package:machuco/database/repository/auth/user_profile_repository.dart';
import 'package:machuco/models/auth/account_status.dart';
import 'package:machuco/models/auth/user_profile.dart';

/// Motivo por el que [AccountSessionWatcher] terminó la sesión.
enum AccountSessionEnd {
  /// La cuenta se eliminó o se anonimizó desde otro dispositivo.
  accountDeleted,

  /// La sesión dejó de ser válida, p. ej. al cambiar la contraseña en otro
  /// dispositivo. La cuenta sigue existiendo.
  sessionExpired,

  /// Un administrador deshabilitó la cuenta (perfil `disabled` o usuario de
  /// Auth deshabilitado).
  accountDisabled,

  /// Un administrador rechazó la solicitud del propietario.
  accountRejected,
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
    this._onProfileRefreshed,
    this.interval = const Duration(minutes: 15),
  });

  static const _deletedCodes = {'user-not-found'};
  static const _expiredCodes = {'user-token-expired', 'invalid-user-token'};
  static const _disabledCodes = {'user-disabled'};

  final FirebaseAuth _auth;
  final UserProfileRepository _profiles;
  final Future<void> Function(AccountSessionEnd reason) _clearLocalData;
  final void Function(AccountSessionEnd reason) _onSessionEnded;

  /// Recibe el perfil leído de Firestore cuando la cuenta sigue vigente, para
  /// refrescar en segundo plano la caché local (`auth_user_profile`, SQ-09).
  final Future<void> Function(UserProfile profile)? _onProfileRefreshed;
  final Duration interval;

  Timer? _timer;
  bool _checking = false;

  /// Empieza a vigilar. Con [checkNow] revisa de inmediato, sin bloquear a
  /// quien llama (al abrir la app).
  void start({bool checkNow = false}) {
    WidgetsBinding.instance.addObserver(this);
    _startTimer();
    if (checkNow) unawaited(check());
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
      if (_auth.currentUser?.uid != user.uid) return;
      if (reason != null) {
        await _endSession(reason);
        return;
      }
      await _refreshLocalProfile();
    } finally {
      _checking = false;
      _freshProfile = null;
    }
  }

  /// Perfil vigente leído en la revisión en curso (solo si no termina la
  /// sesión).
  UserProfile? _freshProfile;

  Future<void> _refreshLocalProfile() async {
    final profile = _freshProfile;
    final refresh = _onProfileRefreshed;
    if (profile == null || refresh == null) return;
    try {
      await refresh(profile);
    } catch (error) {
      // La caché solo sirve para mostrar; un fallo no afecta la sesión.
      debugPrint('No se pudo refrescar el perfil local: ${error.runtimeType}');
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
      if (_disabledCodes.contains(e.code)) {
        return AccountSessionEnd.accountDisabled;
      }
      debugPrint('No se pudo revisar la sesión: ${e.code}');
      return null;
    }
    try {
      // Un administrador eliminado por otro conserva su usuario de Auth, pero
      // su perfil queda anonimizado; deshabilitar o rechazar tampoco borra el
      // usuario de Auth, así que se detecta por el estado del perfil.
      final profile = await _profiles.getProfile(user.uid);
      final reason = switch (profile?.accountStatus) {
        AccountStatus.anonymized => AccountSessionEnd.accountDeleted,
        AccountStatus.disabled => AccountSessionEnd.accountDisabled,
        AccountStatus.rejected => AccountSessionEnd.accountRejected,
        _ => null,
      };
      if (reason == null) _freshProfile = profile;
      return reason;
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
