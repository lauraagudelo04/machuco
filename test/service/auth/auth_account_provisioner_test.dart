import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:machuco/models/auth/administrator_models.dart';
import 'package:machuco/service/auth/auth_account_provisioner.dart';
import 'package:machuco/service/auth/password_change_service.dart';
import 'package:machuco/service/auth/auth_service.dart';
import 'package:machuco/service/auth/temporary_password_generator.dart';

void main() {
  late _SecondaryAuth secondary;
  late FirebaseAuthAccountProvisioner provisioner;

  setUp(() {
    secondary = _SecondaryAuth();
    provisioner = FirebaseAuthAccountProvisioner(
      open: () async => (auth: secondary, dispose: secondary.dispose),
    );
  });

  test(
    'crea el usuario en la sesión secundaria y la cierra al terminar',
    () async {
      final account = await provisioner.createAccount(
        email: 'nora@example.com',
        password: 'Temp-Password-1!',
      );

      expect(account.uid, 'new-uid');
      expect(secondary.createdEmails, ['nora@example.com']);
      expect(secondary.disposed, isFalse);

      await account.close();

      expect(secondary.signOutCalls, 1);
      expect(secondary.disposed, isTrue);
    },
  );

  test('rollback borra el usuario recién creado', () async {
    final account = await provisioner.createAccount(
      email: 'nora@example.com',
      password: 'Temp-Password-1!',
    );
    await account.rollback();
    expect(secondary.user.deleteCalls, 1);
  });

  test('un rollback que falla no lanza', () async {
    secondary.user.deleteError = FirebaseAuthException(
      code: 'network-request-failed',
    );
    final account = await provisioner.createAccount(
      email: 'nora@example.com',
      password: 'Temp-Password-1!',
    );
    await account.rollback();
    await account.close();
    expect(secondary.disposed, isTrue);
  });

  test(
    'email-already-in-use: emailInUse, sin tocar cuentas y cierra la app',
    () async {
      secondary.createError = FirebaseAuthException(
        code: 'email-already-in-use',
      );

      await expectLater(
        provisioner.createAccount(
          email: 'x@example.com',
          password: 'Temp-Password-1!',
        ),
        throwsA(
          isA<AdministratorsRepositoryException>()
              .having(
                (e) => e.type,
                'type',
                AdministratorsFailureType.emailInUse,
              )
              .having((e) => e.message, 'message', contains('en uso')),
        ),
      );

      expect(secondary.user.deleteCalls, 0);
      expect(secondary.disposed, isTrue);
    },
  );

  test('red y otros errores se mapean y siempre se descarta la app', () async {
    secondary.createError = FirebaseAuthException(
      code: 'network-request-failed',
    );
    await expectLater(
      provisioner.createAccount(
        email: 'x@example.com',
        password: 'Temp-Password-1!',
      ),
      throwsA(
        isA<AdministratorsRepositoryException>().having(
          (e) => e.type,
          'type',
          AdministratorsFailureType.network,
        ),
      ),
    );
    expect(secondary.disposed, isTrue);

    secondary
      ..disposed = false
      ..createError = FirebaseAuthException(code: 'operation-not-allowed');
    await expectLater(
      provisioner.createAccount(
        email: 'x@example.com',
        password: 'Temp-Password-1!',
      ),
      throwsA(
        isA<AdministratorsRepositoryException>().having(
          (e) => e.type,
          'type',
          AdministratorsFailureType.unknown,
        ),
      ),
    );
    expect(secondary.disposed, isTrue);
  });

  group('cambio de contraseña', () {
    test('mapea weak-password, requires-recent-login y red', () async {
      final auth = _SecondaryAuth();
      auth.currentUser = auth.user;
      final service = FirebasePasswordChangeService(firebaseAuth: auth);

      Future<void> expectFailure(String code, AuthFailureType type) async {
        auth.user.updatePasswordError = FirebaseAuthException(code: code);
        await expectLater(
          service.changePassword(newPassword: 'Nueva-clave-segura1'),
          throwsA(isA<AuthFailure>().having((f) => f.type, 'type', type)),
        );
      }

      await expectFailure('weak-password', AuthFailureType.weakPassword);
      await expectFailure(
        'requires-recent-login',
        AuthFailureType.requiresRecentLogin,
      );
      await expectFailure('network-request-failed', AuthFailureType.network);
      await expectFailure('otro', AuthFailureType.unknown);

      auth.user.updatePasswordError = null;
      await service.changePassword(newPassword: 'Nueva-clave-segura1');
      expect(auth.user.updatedPasswords, ['Nueva-clave-segura1']);
    });

    test('sin sesión falla con un mensaje claro', () async {
      final auth = _SecondaryAuth();
      await expectLater(
        FirebasePasswordChangeService(
          firebaseAuth: auth,
        ).changePassword(newPassword: 'Nueva-clave-segura1'),
        throwsA(isA<AuthFailure>()),
      );
    });
  });

  group('contraseña temporal', () {
    test('tiene 12 o más caracteres y mezcla clases', () {
      for (var i = 0; i < 50; i++) {
        final password = TemporaryPasswordGenerator.generate();
        expect(password.length, greaterThanOrEqualTo(12));
        expect(RegExp('[a-z]').hasMatch(password), isTrue);
        expect(RegExp('[A-Z]').hasMatch(password), isTrue);
        expect(RegExp('[0-9]').hasMatch(password), isTrue);
        expect(RegExp(r'[^a-zA-Z0-9]').hasMatch(password), isTrue);
      }
    });

    test('nunca baja de 12 aunque se pida menos y no se repite', () {
      expect(TemporaryPasswordGenerator.generate(length: 4).length, 12);
      final set = {
        for (var i = 0; i < 100; i++) TemporaryPasswordGenerator.generate(),
      };
      expect(set.length, 100);
    });
  });
}

final class _SecondaryAuth implements FirebaseAuth {
  final user = _User();
  FirebaseAuthException? createError;
  final createdEmails = <String>[];
  int signOutCalls = 0;
  bool disposed = false;

  @override
  User? currentUser;

  Future<void> dispose() async => disposed = true;

  @override
  Future<UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    final error = createError;
    if (error != null) throw error;
    createdEmails.add(email);
    return _Credential(user);
  }

  @override
  Future<void> signOut() async => signOutCalls++;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _Credential implements UserCredential {
  _Credential(this.user);

  @override
  final User user;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _User implements User {
  int deleteCalls = 0;
  FirebaseAuthException? deleteError;
  FirebaseAuthException? updatePasswordError;
  final updatedPasswords = <String>[];

  @override
  String get uid => 'new-uid';

  @override
  Future<void> delete() async {
    deleteCalls++;
    final error = deleteError;
    if (error != null) throw error;
  }

  @override
  Future<void> updatePassword(String newPassword) async {
    final error = updatePasswordError;
    if (error != null) throw error;
    updatedPasswords.add(newPassword);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
