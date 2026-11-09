import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:machuco/database/repository/auth/administrators_repository.dart';
import 'package:machuco/database/repository/auth/user_profile_repository.dart';
import 'package:machuco/models/auth/account_status.dart';
import 'package:machuco/models/auth/person_type.dart';
import 'package:machuco/models/auth/registered_user.dart';
import 'package:machuco/models/auth/registration_data.dart';
import 'package:machuco/models/auth/user_profile.dart';
import 'package:machuco/service/auth/auth_service.dart';
import 'package:machuco/service/auth/firebase_auth_service.dart';

UserProfile _stored({
  required RegisteredUserRole role,
  required AccountStatus? status,
  String? rejectionReason,
}) => UserProfile(
  uid: 'u1',
  fullName: 'Luz Mora',
  email: 'luz@example.com',
  phoneNumber: '+573001234567',
  role: role,
  accountStatus: status,
  rejectionReason: rejectionReason,
);

void main() {
  late _FakeFirebaseAuth firebase;
  late _FakeProfiles profiles;
  late FirebaseAuthService service;
  late _StubAdministrators administrators;

  setUp(() {
    firebase = _FakeFirebaseAuth();
    profiles = _FakeProfiles();
    administrators = _StubAdministrators();
    service = FirebaseAuthService(
      firebaseAuth: firebase,
      profileRepository: profiles,
      administratorsRepository: administrators,
    );
  });

  Matcher failureOf(AuthFailureType type) => throwsA(
    isA<AuthFailure>().having((failure) => failure.type, 'type', type),
  );

  group('estado de la cuenta al iniciar sesión', () {
    test('propietario pendiente obtiene sesión con su estado', () async {
      profiles.stored = _stored(
        role: RegisteredUserRole.owner,
        status: AccountStatus.pendingApproval,
      );

      final session = await service.login(
        email: 'luz@example.com',
        password: 'secreto123',
      );

      expect(session.accountStatus, AccountStatus.pendingApproval);
      expect(session.role, RegisteredUserRole.owner);
      expect(session.profile?.uid, 'u1');
      expect(firebase.signOutCalls, 0);
    });

    test('[SOC-R1] cuenta activa entra; perfil ausente exige completar perfil '
        'y conserva la sesión de Firebase', () async {
      profiles.stored = _stored(
        role: RegisteredUserRole.client,
        status: AccountStatus.active,
      );
      expect(
        (await service.login(email: 'a@b.co', password: 'x')).accountStatus,
        AccountStatus.active,
      );

      profiles.stored = null;
      await expectLater(
        service.login(email: 'a@b.co', password: 'x'),
        failureOf(AuthFailureType.profileIncomplete),
      );
      expect(firebase.signOutCalls, 0);
    });

    test('[SOC-R2] admin sin accountStatus: configuración inválida', () async {
      profiles.stored = _stored(role: RegisteredUserRole.admin, status: null);

      await expectLater(
        service.login(email: 'a@b.co', password: 'x'),
        failureOf(AuthFailureType.invalidConfiguration),
      );
      expect(firebase.signOutCalls, 1);
    });

    test('rechazada cierra sesión y entrega el motivo', () async {
      profiles.stored = _stored(
        role: RegisteredUserRole.owner,
        status: AccountStatus.rejected,
        rejectionReason: 'El NIT no coincide',
      );

      await expectLater(
        service.login(email: 'luz@example.com', password: 'secreto123'),
        throwsA(
          isA<AuthFailure>()
              .having((f) => f.type, 'type', AuthFailureType.accountRejected)
              .having((f) => f.rejectionReason, 'reason', 'El NIT no coincide'),
        ),
      );
      expect(firebase.signOutCalls, 1);
    });

    test('deshabilitada cierra sesión', () async {
      profiles.stored = _stored(
        role: RegisteredUserRole.client,
        status: AccountStatus.disabled,
      );
      await expectLater(
        service.login(email: 'a@b.co', password: 'x'),
        failureOf(AuthFailureType.accountDisabled),
      );
      expect(firebase.signOutCalls, 1);
    });

    test(
      'estado desconocido o pendiente de un no propietario se bloquea',
      () async {
        profiles.stored = _stored(
          role: RegisteredUserRole.client,
          status: null,
        );
        await expectLater(
          service.login(email: 'a@b.co', password: 'x'),
          failureOf(AuthFailureType.unknown),
        );
        profiles.stored = _stored(
          role: RegisteredUserRole.client,
          status: AccountStatus.pendingApproval,
        );
        await expectLater(
          service.login(email: 'a@b.co', password: 'x'),
          failureOf(AuthFailureType.unknown),
        );
        expect(firebase.signOutCalls, 2);
      },
    );

    test('restoreSession descarta una cuenta rechazada', () async {
      firebase.currentUser = _FakeUser(firebase);
      profiles.stored = _stored(
        role: RegisteredUserRole.owner,
        status: AccountStatus.rejected,
      );
      expect(await service.restoreSession(), isNull);
      expect(firebase.signOutCalls, 1);
    });

    test('restoreSession conserva el propietario pendiente', () async {
      firebase.currentUser = _FakeUser(firebase);
      profiles.stored = _stored(
        role: RegisteredUserRole.owner,
        status: AccountStatus.pendingApproval,
      );
      final session = await service.restoreSession();
      expect(session?.accountStatus, AccountStatus.pendingApproval);
    });
  });

  group('errores de Firebase', () {
    test('mapea too-many-requests y user-disabled', () async {
      firebase.signInError = FirebaseAuthException(code: 'too-many-requests');
      await expectLater(
        service.login(email: 'a@b.co', password: 'x'),
        failureOf(AuthFailureType.tooManyRequests),
      );
      firebase.signInError = FirebaseAuthException(code: 'user-disabled');
      await expectLater(
        service.login(email: 'a@b.co', password: 'x'),
        failureOf(AuthFailureType.accountDisabled),
      );
      firebase.signInError = FirebaseAuthException(code: 'wrong-password');
      await expectLater(
        service.login(email: 'a@b.co', password: 'x'),
        failureOf(AuthFailureType.invalidCredentials),
      );
    });

    test(
      'recuperación: too-many-requests se mapea; user-not-found no revela nada',
      () async {
        firebase.resetError = FirebaseAuthException(code: 'too-many-requests');
        await expectLater(
          service.requestPasswordReset(email: 'a@b.co'),
          failureOf(AuthFailureType.tooManyRequests),
        );
        firebase.resetError = FirebaseAuthException(code: 'user-not-found');
        await service.requestPasswordReset(email: 'a@b.co');
      },
    );
  });

  group('registro por rol', () {
    test('cliente: activo, con fecha de nacimiento y sin NIT', () async {
      await service.registerAccount(
        RegistrationData.client(
          firstNames: ' Ana ',
          lastNames: 'Pérez',
          phoneCountryCodeId: 1,
          phoneNumber: '+573001234567',
          email: ' Ana@Example.com ',
          password: 'secreto123',
          birthDate: DateTime(1990, 5, 20),
        ),
      );

      final profile = profiles.created.single;
      expect(profile.role, RegisteredUserRole.client);
      expect(profile.accountStatus, AccountStatus.active);
      expect(profile.email, 'ana@example.com');
      expect(profile.fullName, 'Ana Pérez');
      expect(profile.firstNames, 'Ana');
      expect(profile.phoneCountryCodeId, 1);
      expect(profile.birthDate, DateTime(1990, 5, 20));
      expect(profile.nit, isNull);
      expect(profile.personType, isNull);
      expect(firebase.signOutCalls, 1);
    });

    test(
      'propietario: pendiente con tipo de persona, NIT, razón social y plan',
      () async {
        await service.registerAccount(
          RegistrationData.owner(
            firstNames: 'Luz',
            lastNames: 'Mora',
            phoneCountryCodeId: 1,
            phoneNumber: '+573001234567',
            email: 'luz@example.com',
            password: 'secreto123',
            personType: PersonType.juridica,
            nit: '9001234568',
            companyName: ' Moteles SAS ',
            planId: 2,
          ),
        );

        final profile = profiles.created.single;
        expect(profile.role, RegisteredUserRole.owner);
        expect(profile.accountStatus, AccountStatus.pendingApproval);
        expect(profile.personType, PersonType.juridica);
        expect(profile.nit, '900123456-8');
        expect(profile.companyName, 'Moteles SAS');
        expect(profile.planId, 2);
        expect(profile.birthDate, isNull);
      },
    );

    test('si el perfil no se guarda, revierte la cuenta creada', () async {
      profiles.createError = const UserProfileRepositoryException(
        UserProfileFailureType.network,
        'sin red',
      );
      await expectLater(
        service.registerAccount(
          RegistrationData.client(
            firstNames: 'Ana',
            lastNames: 'Pérez',
            phoneCountryCodeId: 1,
            phoneNumber: '+573001234567',
            email: 'ana@example.com',
            password: 'secreto123',
            birthDate: DateTime(1990, 5, 20),
          ),
        ),
        failureOf(AuthFailureType.network),
      );
      expect(firebase.createdUser?.deleteCalls, 1);
    });

    test('el registro histórico sigue funcionando', () async {
      await service.register(
        fullName: 'Ana Pérez',
        email: 'ANA@example.com',
        phoneNumber: '+573001234567',
        password: 'secreto123',
        role: RegisteredUserRole.client,
      );
      expect(profiles.created.single.fullName, 'Ana Pérez');
      expect(profiles.created.single.email, 'ana@example.com');
    });

    test('nunca crea administradores', () async {
      await expectLater(
        service.register(
          fullName: 'Eve',
          email: 'eve@example.com',
          phoneNumber: '+573001234567',
          password: 'secreto123',
          role: RegisteredUserRole.admin,
        ),
        failureOf(AuthFailureType.unknown),
      );
      expect(firebase.createdUser, isNull);
    });
  });

  group('eliminación de cuenta', () {
    late _FakeUser user;

    setUp(() {
      user = _FakeUser(firebase);
      firebase.currentUser = user;
    });

    test(
      'reautentica, borra el perfil y luego el usuario, en ese orden',
      () async {
        await service.deleteAccount(password: 'secreto123');

        expect(firebase.events, [
          'reauth:luz@example.com',
          'deleteProfile:u1',
          'deleteUser',
          'signOut',
        ]);
      },
    );

    test('contraseña incorrecta no borra nada', () async {
      user.reauthError = FirebaseAuthException(code: 'wrong-password');
      await expectLater(
        service.deleteAccount(password: 'mala'),
        failureOf(AuthFailureType.invalidCredentials),
      );
      expect(profiles.deleted, isEmpty);
      expect(user.deleteCalls, 0);
    });

    test('un fallo de red al borrar el perfil no borra el usuario', () async {
      profiles.deleteError = const UserProfileRepositoryException(
        UserProfileFailureType.network,
        'sin red',
      );
      await expectLater(
        service.deleteAccount(password: 'secreto123'),
        failureOf(AuthFailureType.network),
      );
      expect(user.deleteCalls, 0);
    });

    test('requires-recent-login y too-many-requests se mapean', () async {
      user.deleteError = FirebaseAuthException(code: 'requires-recent-login');
      await expectLater(
        service.deleteAccount(password: 'secreto123'),
        failureOf(AuthFailureType.requiresRecentLogin),
      );
      user.deleteError = null;
      user.reauthError = FirebaseAuthException(code: 'too-many-requests');
      await expectLater(
        service.deleteAccount(password: 'secreto123'),
        failureOf(AuthFailureType.tooManyRequests),
      );
    });

    test('es idempotente si el perfil ya se había borrado', () async {
      user.deleteError = FirebaseAuthException(code: 'network-request-failed');
      await expectLater(
        service.deleteAccount(password: 'secreto123'),
        failureOf(AuthFailureType.network),
      );
      expect(profiles.deleted, ['u1']);

      user.deleteError = null;
      await service.deleteAccount(password: 'secreto123');
      expect(profiles.deleted, ['u1', 'u1']);
      expect(user.deleteCalls, 2);
    });

    test('sin sesión activa falla con un mensaje claro', () async {
      firebase.currentUser = null;
      await expectLater(
        service.deleteAccount(password: 'secreto123'),
        failureOf(AuthFailureType.unknown),
      );
    });

    test(
      'un cliente sigue borrando su perfil, sin tocar administradores',
      () async {
        profiles.stored = _stored(
          role: RegisteredUserRole.client,
          status: AccountStatus.active,
        );
        await service.deleteAccount(password: 'secreto123');
        expect(profiles.deleted, ['u1']);
        expect(administrators.calls, isEmpty);
      },
    );
  });

  group('eliminación de cuenta de administrador', () {
    late _FakeUser user;

    setUp(() {
      user = _FakeUser(firebase);
      firebase.currentUser = user;
      profiles.stored = _stored(
        role: RegisteredUserRole.admin,
        status: AccountStatus.active,
      );
      administrators.onAnonymizeOwn = () =>
          FirebaseAuthEvents.log.add('anonymizeOwn');
    });

    test(
      'reautentica, anonimiza (no borra el perfil) y luego borra el usuario',
      () async {
        await service.deleteAccount(password: 'secreto123');

        expect(firebase.events, [
          'reauth:luz@example.com',
          'anonymizeOwn',
          'deleteUser',
          'signOut',
        ]);
        expect(profiles.deleted, isEmpty);
      },
    );

    test(
      'el último administrador falla con lastAdministrator y sin cambios',
      () async {
        administrators.failNext = const AdministratorsRepositoryException(
          AdministratorsFailureType.lastAdmin,
          'Eres el único administrador activo.',
        );

        await expectLater(
          service.deleteAccount(password: 'secreto123'),
          failureOf(AuthFailureType.lastAdministrator),
        );

        expect(user.deleteCalls, 0);
        expect(profiles.deleted, isEmpty);
        expect(firebase.signOutCalls, 0);
      },
    );

    test('contraseña incorrecta no anonimiza nada', () async {
      user.reauthError = FirebaseAuthException(code: 'wrong-password');
      await expectLater(
        service.deleteAccount(password: 'mala'),
        failureOf(AuthFailureType.invalidCredentials),
      );
      expect(administrators.calls, isEmpty);
    });

    test('un fallo de red al anonimizar no borra el usuario', () async {
      administrators.failNext = const AdministratorsRepositoryException(
        AdministratorsFailureType.network,
        'sin red',
      );
      await expectLater(
        service.deleteAccount(password: 'secreto123'),
        failureOf(AuthFailureType.network),
      );
      expect(user.deleteCalls, 0);
    });

    test(
      'reintento tras fallar User.delete: ya anonimizado, solo borra el usuario',
      () async {
        user.deleteError = FirebaseAuthException(
          code: 'network-request-failed',
        );
        await expectLater(
          service.deleteAccount(password: 'secreto123'),
          failureOf(AuthFailureType.network),
        );
        expect(administrators.calls, ['anonymizeOwn']);

        profiles.stored = _stored(
          role: RegisteredUserRole.admin,
          status: AccountStatus.anonymized,
        );
        user.deleteError = null;
        await service.deleteAccount(password: 'secreto123');

        expect(administrators.calls, ['anonymizeOwn']);
        expect(user.deleteCalls, 2);
      },
    );
  });

  group('cuenta anonimizada', () {
    test('no puede iniciar sesión: fallo neutro y sesión cerrada', () async {
      profiles.stored = _stored(
        role: RegisteredUserRole.admin,
        status: AccountStatus.anonymized,
      );

      await expectLater(
        service.login(email: 'a@b.co', password: 'x'),
        throwsA(
          isA<AuthFailure>()
              .having((f) => f.type, 'type', AuthFailureType.accountDeleted)
              .having((f) => f.message, 'message', 'Esta cuenta ya no existe.'),
        ),
      );
      expect(firebase.signOutCalls, 1);
    });

    test('restoreSession la descarta', () async {
      firebase.currentUser = _FakeUser(firebase);
      profiles.stored = _stored(
        role: RegisteredUserRole.admin,
        status: AccountStatus.anonymized,
      );
      expect(await service.restoreSession(), isNull);
      expect(firebase.signOutCalls, 1);
    });

    test('un perfil anonimizado sin correo ni teléfono se lee sin error', () {
      final profile = UserProfile.fromFirestore('gone', {
        'fullName': 'Administrador eliminado',
        'role': 'admin',
        'accountStatus': 'anonymized',
        'anonymizedBy': 'otro',
      });
      expect(profile.accountStatus, AccountStatus.anonymized);
      expect(profile.email, isEmpty);
      expect(profile.phoneNumber, isEmpty);
      expect(profile.mustChangePassword, isFalse);
      expect(AccountStatus.anonymized.storageValue, 'anonymized');
      expect(accountStatusFromStorage('anonymized'), AccountStatus.anonymized);
    });

    test('mustChangePassword ausente es false y true se lee', () {
      expect(
        UserProfile.fromFirestore('a', {'role': 'admin'}).mustChangePassword,
        isFalse,
      );
      expect(
        UserProfile.fromFirestore('a', {
          'role': 'admin',
          'mustChangePassword': true,
          'createdBy': 'creador',
        }),
        isA<UserProfile>()
            .having((p) => p.mustChangePassword, 'mustChange', isTrue)
            .having((p) => p.createdBy, 'createdBy', 'creador'),
      );
    });
  });
}

class _StubAdministrators implements AdministratorsRepository {
  final calls = <String>[];
  AdministratorsRepositoryException? failNext;
  void Function()? onAnonymizeOwn;

  @override
  Future<void> anonymizeOwnAccount() async {
    final failure = failNext;
    if (failure != null) {
      failNext = null;
      throw failure;
    }
    calls.add('anonymizeOwn');
    onAnonymizeOwn?.call();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _FakeProfiles implements UserProfileRepository {
  UserProfile? stored;
  final created = <UserProfile>[];
  final deleted = <String>[];
  UserProfileRepositoryException? createError;
  UserProfileRepositoryException? deleteError;

  @override
  Future<void> createProfile(UserProfile profile) async {
    final error = createError;
    if (error != null) throw error;
    created.add(profile);
  }

  @override
  Future<UserProfile?> getProfile(String uid) async => stored;

  @override
  Future<void> updateProfile({
    required String uid,
    required String fullName,
    required String phoneNumber,
  }) async {}

  @override
  Future<void> deleteProfile(String uid) async {
    final error = deleteError;
    if (error != null) throw error;
    deleted.add(uid);
    FirebaseAuthEvents.log.add('deleteProfile:$uid');
  }
}

/// Registro global de eventos para comprobar el orden de las operaciones.
abstract final class FirebaseAuthEvents {
  static final log = <String>[];
}

final class _FakeFirebaseAuth implements FirebaseAuth {
  _FakeFirebaseAuth() {
    FirebaseAuthEvents.log.clear();
  }

  @override
  User? currentUser;
  _FakeUser? createdUser;
  int signOutCalls = 0;
  FirebaseAuthException? signInError;
  FirebaseAuthException? resetError;

  List<String> get events => FirebaseAuthEvents.log;

  @override
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    final error = signInError;
    if (error != null) throw error;
    final user = _FakeUser(this);
    currentUser = user;
    return _FakeCredential(user);
  }

  @override
  Future<UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    final user = _FakeUser(this);
    createdUser = user;
    currentUser = user;
    return _FakeCredential(user);
  }

  @override
  Future<void> sendPasswordResetEmail({
    required String email,
    ActionCodeSettings? actionCodeSettings,
  }) async {
    final error = resetError;
    if (error != null) throw error;
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
    events.add('signOut');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _FakeCredential implements UserCredential {
  _FakeCredential(this.user);

  @override
  final User user;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _FakeUser implements User {
  _FakeUser(this._auth);

  final _FakeFirebaseAuth _auth;
  FirebaseAuthException? reauthError;
  FirebaseAuthException? deleteError;
  int deleteCalls = 0;

  @override
  String get uid => 'u1';

  @override
  String? get email => 'luz@example.com';

  @override
  String? get displayName => 'Luz';

  @override
  Future<void> reload() async {}

  @override
  Future<void> updateDisplayName(String? displayName) async {}

  @override
  Future<IdTokenResult> getIdTokenResult([bool forceRefresh = false]) async =>
      _FakeToken();

  @override
  Future<UserCredential> reauthenticateWithCredential(
    AuthCredential credential,
  ) async {
    final error = reauthError;
    if (error != null) throw error;
    _auth.events.add('reauth:$email');
    return _FakeCredential(this);
  }

  @override
  Future<void> delete() async {
    deleteCalls++;
    final error = deleteError;
    if (error != null) throw error;
    _auth.events.add('deleteUser');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _FakeToken implements IdTokenResult {
  @override
  String? get token => 'header.payload.signature';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
