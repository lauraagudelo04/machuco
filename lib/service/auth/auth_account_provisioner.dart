import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:machuco/models/auth/administrator_models.dart';

/// A Firebase Auth user created in a secondary session, still open so the
/// caller can undo it if saving the profile fails.
abstract interface class ProvisionedAccount {
  String get uid;

  /// Deletes the user just created (rollback). Never throws.
  Future<void> rollback();

  /// Signs out and discards the secondary session. Always call it (`finally`).
  /// Never throws.
  Future<void> close();
}

/// Creates Firebase Auth users WITHOUT touching the signed-in administrator's
/// session (the SDK signs in whoever it creates). Isolates Firebase so the
/// repository can be tested with fakes.
abstract interface class AuthAccountProvisioner {
  /// Throws [AdministratorsRepositoryException]: `emailInUse` if the email has
  /// an account (nothing is touched), `network`, `invalidInput` or `unknown`.
  Future<ProvisionedAccount> createAccount({
    required String email,
    required String password,
  });
}

/// An opened secondary Firebase Auth instance and how to dispose of it.
typedef SecondaryAuth = ({FirebaseAuth auth, Future<void> Function() dispose});

/// [AuthAccountProvisioner] using a secondary `FirebaseApp` (same options as
/// the default one), so the main administrator keeps their session.
final class FirebaseAuthAccountProvisioner implements AuthAccountProvisioner {
  FirebaseAuthAccountProvisioner({Future<SecondaryAuth> Function()? open})
    : _open = open ?? _openSecondaryApp;

  final Future<SecondaryAuth> Function() _open;

  static Future<SecondaryAuth> _openSecondaryApp() async {
    final app = await Firebase.initializeApp(
      name: 'admin-provisioning-${DateTime.now().microsecondsSinceEpoch}',
      options: Firebase.app().options,
    );
    return (
      auth: FirebaseAuth.instanceFor(app: app),
      dispose: () => app.delete(),
    );
  }

  @override
  Future<ProvisionedAccount> createAccount({
    required String email,
    required String password,
  }) async {
    final SecondaryAuth secondary;
    try {
      secondary = await _open();
    } catch (error) {
      debugPrint(
        'No fue posible abrir la sesión secundaria: ${error.runtimeType}',
      );
      throw const AdministratorsRepositoryException(
        AdministratorsFailureType.unknown,
        'No pudimos iniciar la creación de la cuenta. Intenta nuevamente.',
      );
    }
    try {
      final credential = await secondary.auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = credential.user;
      if (user == null) {
        throw const AdministratorsRepositoryException(
          AdministratorsFailureType.unknown,
          'No pudimos crear la cuenta. Intenta nuevamente.',
        );
      }
      return _Provisioned(user, secondary);
    } on FirebaseAuthException catch (e) {
      await _dispose(secondary);
      throw _map(e);
    } catch (_) {
      await _dispose(secondary);
      rethrow;
    }
  }

  static AdministratorsRepositoryException _map(FirebaseAuthException e) {
    debugPrint('Creación de administrador en Auth falló: ${e.code}');
    return switch (e.code) {
      'email-already-in-use' => const AdministratorsRepositoryException(
        AdministratorsFailureType.emailInUse,
        'Ese correo ya está en uso.',
      ),
      'invalid-email' => const AdministratorsRepositoryException(
        AdministratorsFailureType.invalidInput,
        'El correo no es válido.',
      ),
      'network-request-failed' => const AdministratorsRepositoryException(
        AdministratorsFailureType.network,
        'No hay conexión. Revisa tu internet e intenta nuevamente.',
      ),
      _ => const AdministratorsRepositoryException(
        AdministratorsFailureType.unknown,
        'No pudimos crear la cuenta. Intenta nuevamente.',
      ),
    };
  }
}

Future<void> _dispose(SecondaryAuth secondary) async {
  try {
    await secondary.auth.signOut();
  } catch (error) {
    debugPrint(
      'No fue posible cerrar la sesión secundaria: ${error.runtimeType}',
    );
  }
  try {
    await secondary.dispose();
  } catch (error) {
    debugPrint('No fue posible borrar la app secundaria: ${error.runtimeType}');
  }
}

final class _Provisioned implements ProvisionedAccount {
  _Provisioned(this._user, this._secondary);

  final User _user;
  final SecondaryAuth _secondary;

  @override
  String get uid => _user.uid;

  @override
  Future<void> rollback() async {
    try {
      await _user.delete();
    } catch (error) {
      debugPrint(
        'No fue posible revertir la cuenta creada: ${error.runtimeType}',
      );
    }
  }

  @override
  Future<void> close() => _dispose(_secondary);
}
