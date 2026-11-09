import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:machuco/database/repository/auth/user_profile_repository.dart';
import 'package:machuco/models/auth/account_status.dart';
import 'package:machuco/models/auth/registered_user.dart';
import 'package:machuco/models/auth/user_profile.dart';
import 'package:machuco/service/auth/account_session_watcher.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeAuth auth;
  late _FakeUser user;
  late _FakeProfiles profiles;
  late List<AccountSessionEnd> cleared;
  late List<AccountSessionEnd> ended;
  late AccountSessionWatcher watcher;

  AccountSessionWatcher build({Duration interval = const Duration(hours: 1)}) =>
      AccountSessionWatcher(
        auth: auth,
        profiles: profiles,
        clearLocalData: (reason) async => cleared.add(reason),
        onSessionEnded: ended.add,
        interval: interval,
      );

  setUp(() {
    user = _FakeUser('u1');
    auth = _FakeAuth()..currentUser = user;
    profiles = _FakeProfiles();
    cleared = [];
    ended = [];
    watcher = build();
  });

  group('[DA-17] cuenta eliminada en otro dispositivo', () {
    test('el usuario ya no existe: cierra sesión y borra lo local', () async {
      user.reloadError = FirebaseAuthException(code: 'user-not-found');

      await watcher.check();

      expect(auth.signOutCalls, 1);
      expect(cleared, [AccountSessionEnd.accountDeleted]);
      expect(ended, [AccountSessionEnd.accountDeleted]);
    });

    test('perfil anonimizado por otro administrador', () async {
      profiles.profile = _profile(AccountStatus.anonymized);

      await watcher.check();

      expect(auth.signOutCalls, 1);
      expect(ended, [AccountSessionEnd.accountDeleted]);
    });

    test('borra lo local aunque cerrar sesión falle', () async {
      user.reloadError = FirebaseAuthException(code: 'user-not-found');
      auth.signOutError = FirebaseAuthException(code: 'internal-error');

      await watcher.check();

      expect(cleared, [AccountSessionEnd.accountDeleted]);
      expect(ended, [AccountSessionEnd.accountDeleted]);
    });
  });

  test(
    'token vencido: la sesión expira, sin tratarla como eliminada',
    () async {
      user.reloadError = FirebaseAuthException(code: 'user-token-expired');

      await watcher.check();

      expect(auth.signOutCalls, 1);
      expect(cleared, [AccountSessionEnd.sessionExpired]);
      expect(ended, [AccountSessionEnd.sessionExpired]);
    },
  );

  group('conserva la sesión', () {
    Future<void> expectKept() async {
      await watcher.check();
      expect(auth.signOutCalls, 0);
      expect(cleared, isEmpty);
      expect(ended, isEmpty);
    }

    test('cuenta activa', () async {
      profiles.profile = _profile(AccountStatus.active);
      await expectKept();
    });

    test('usuario sin perfil ("Completar perfil")', () async {
      profiles.profile = null;
      await expectKept();
    });

    test('sin conexión al revisar el usuario', () async {
      user.reloadError = FirebaseAuthException(code: 'network-request-failed');
      await expectKept();
    });

    test('error al leer el perfil', () async {
      profiles.error = const UserProfileRepositoryException(
        UserProfileFailureType.network,
        'sin red',
      );
      await expectKept();
    });

    test('sin sesión no consulta nada', () async {
      auth.currentUser = null;
      await expectKept();
      expect(user.reloadCalls, 0);
    });

    test('la sesión cambió durante la revisión', () async {
      user.reloadError = FirebaseAuthException(code: 'user-not-found');
      user.onReload = () => auth.currentUser = _FakeUser('u2');
      await expectKept();
    });
  });

  test('las revisiones no se solapan', () async {
    final gate = Completer<void>();
    user.reloadGate = gate;

    final first = watcher.check();
    await watcher.check();
    gate.complete();
    await first;

    expect(user.reloadCalls, 1);
  });

  test('se puede volver a revisar después de terminar', () async {
    await watcher.check();
    await watcher.check();

    expect(user.reloadCalls, 2);
  });

  group('ciclo de vida', () {
    tearDown(() => watcher.stop());

    test('revisa al volver a primer plano', () async {
      watcher.start();

      watcher.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await pumpEventQueue();

      expect(user.reloadCalls, 1);
    });

    test('revisa periódicamente y se detiene en segundo plano', () async {
      watcher = build(interval: const Duration(milliseconds: 5));
      watcher.start();

      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(user.reloadCalls, greaterThan(0));

      watcher.didChangeAppLifecycleState(AppLifecycleState.paused);
      await pumpEventQueue();
      final calls = user.reloadCalls;
      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(user.reloadCalls, calls);
    });
  });
}

UserProfile _profile(AccountStatus status) => UserProfile(
  uid: 'u1',
  fullName: 'Ana Pérez',
  email: 'ana@example.com',
  phoneNumber: '+573001234567',
  role: RegisteredUserRole.client,
  accountStatus: status,
);

final class _FakeAuth implements FirebaseAuth {
  @override
  User? currentUser;
  FirebaseAuthException? signOutError;
  int signOutCalls = 0;

  @override
  Future<void> signOut() async {
    signOutCalls++;
    final error = signOutError;
    if (error != null) throw error;
    currentUser = null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _FakeUser implements User {
  _FakeUser(this.uid);

  @override
  final String uid;
  FirebaseAuthException? reloadError;
  Completer<void>? reloadGate;
  void Function()? onReload;
  int reloadCalls = 0;

  @override
  Future<void> reload() async {
    reloadCalls++;
    await reloadGate?.future;
    onReload?.call();
    final error = reloadError;
    if (error != null) throw error;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _FakeProfiles implements UserProfileRepository {
  UserProfile? profile;
  UserProfileRepositoryException? error;

  @override
  Future<UserProfile?> getProfile(String uid) async {
    final failure = error;
    if (failure != null) throw failure;
    return profile;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
