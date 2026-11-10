import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:machuco/service/auth/auth_service.dart';

/// Changes the password of the signed-in user (first sign-in of an
/// administrator created with a temporary password).
abstract interface class PasswordChangeService {
  /// Throws [AuthFailure]: `weakPassword`, `requiresRecentLogin`, `network`
  /// or `unknown`. The new password is never logged.
  Future<void> changePassword({required String newPassword});
}

/// [PasswordChangeService] with `User.updatePassword`.
final class FirebasePasswordChangeService implements PasswordChangeService {
  FirebasePasswordChangeService({FirebaseAuth? firebaseAuth})
    : _injected = firebaseAuth;

  final FirebaseAuth? _injected;

  @override
  Future<void> changePassword({required String newPassword}) async {
    final user = (_injected ?? FirebaseAuth.instance).currentUser;
    if (user == null) {
      throw const AuthFailure(
        AuthFailureType.unknown,
        'No hay una sesión activa. Inicia sesión e intenta nuevamente.',
      );
    }
    try {
      await user.updatePassword(newPassword);
    } on FirebaseAuthException catch (e) {
      debugPrint('Cambio de contraseña falló: ${e.code}');
      throw switch (e.code) {
        'weak-password' => const AuthFailure(
          AuthFailureType.weakPassword,
          'La contraseña es demasiado débil.',
        ),
        'requires-recent-login' => const AuthFailure(
          AuthFailureType.requiresRecentLogin,
          'Por seguridad, inicia sesión de nuevo para cambiar tu contraseña.',
        ),
        'network-request-failed' => const AuthFailure(
          AuthFailureType.network,
          'No hay conexión. Revisa tu internet e intenta nuevamente.',
        ),
        _ => const AuthFailure(
          AuthFailureType.unknown,
          'No pudimos cambiar tu contraseña. Intenta nuevamente.',
        ),
      };
    }
  }
}
