import 'package:flutter_test/flutter_test.dart';
import 'package:machuco/database/repository/auth/administrators_repository.dart';
import 'package:machuco/database/repository/auth/administrators_store.dart';
import 'package:machuco/models/auth/account_status.dart';
import 'package:machuco/models/auth/registered_user.dart';

import 'administrators_test_support.dart';

const _newAdmin = NewAdministratorData(
  firstNames: ' Nora ',
  lastNames: 'Quintero',
  phoneCountryCodeId: 1,
  phoneNumber: '+573001112233',
  email: ' Nora@Example.COM ',
);

void main() {
  late FakeAdministratorsStore store;
  late FakeProvisioner provisioner;
  late String? actor;

  FirestoreAdministratorsRepository build() =>
      FirestoreAdministratorsRepository(
        store: store,
        provisioner: provisioner,
        currentUid: () => actor,
      );

  Matcher failure(AdministratorsFailureType type) => throwsA(
    isA<AdministratorsRepositoryException>().having(
      (e) => e.type,
      'type',
      type,
    ),
  );

  setUp(() {
    store = FakeAdministratorsStore(
      profiles: [adminProfile('a'), adminProfile('b')],
    )..registryCount = 2;
    provisioner = FakeProvisioner();
    actor = 'a';
  });

  group('consulta', () {
    test('lista solo administradores, sin anonimizados, ordenados', () async {
      store.profiles['z'] = adminProfile('z', name: 'Zoe');
      store.profiles['gone'] = adminProfile(
        'gone',
        status: AccountStatus.anonymized,
        name: 'Administrador eliminado',
      );
      store.profiles['c1'] = adminProfile(
        'c1',
        role: RegisteredUserRole.client,
      );
      store.profiles['p'] = adminProfile('p', mustChangePassword: true);

      final list = await build().listAdministrators();

      expect(list.map((p) => p.uid), ['a', 'b', 'p', 'z']);
    });

    test('un error de red al listar se propaga', () async {
      store.failNextFetch = const AdministratorsRepositoryException(
        AdministratorsFailureType.network,
        'sin red',
      );
      await expectLater(
        build().listAdministrators(),
        failure(AdministratorsFailureType.network),
      );
    });

    test(
      'el detalle de una cuenta anonimizada o ausente es notFound',
      () async {
        store.profiles['gone'] = adminProfile(
          'gone',
          status: AccountStatus.anonymized,
        );
        final repository = build();
        expect((await repository.getAdministrator('b')).uid, 'b');
        await expectLater(
          repository.getAdministrator('gone'),
          failure(AdministratorsFailureType.notFound),
        );
        await expectLater(
          repository.getAdministrator('nadie'),
          failure(AdministratorsFailureType.notFound),
        );
      },
    );
  });

  group('crear administrador', () {
    test('crea cuenta y perfil con contraseña temporal y suma 1', () async {
      final created = await build().createAdministrator(_newAdmin);

      final stored = store.profiles[created.profile.uid]!;
      expect(stored.role, RegisteredUserRole.admin);
      expect(stored.accountStatus, AccountStatus.active);
      expect(stored.mustChangePassword, isTrue);
      expect(stored.createdBy, 'a');
      expect(stored.email, 'nora@example.com');
      expect(stored.fullName, 'Nora Quintero');
      expect(store.registryCount, 3);

      expect(created.temporaryPassword.length, greaterThanOrEqualTo(12));
      expect(created.temporaryPassword, provisioner.passwords.single);
      expect(provisioner.emails.single, 'nora@example.com');
      final account = provisioner.accounts.single;
      expect(account.rolledBack, isFalse);
      expect(account.closed, isTrue);
    });

    test(
      'la contraseña no se guarda en el perfil ni en el texto del resultado',
      () async {
        final created = await build().createAdministrator(_newAdmin);
        final stored = store.profiles[created.profile.uid]!;

        final fields = [
          stored.fullName,
          stored.email,
          stored.phoneNumber,
          stored.firstNames,
          stored.lastNames,
          stored.createdBy,
        ].join(' ');
        expect(fields, isNot(contains(created.temporaryPassword)));
        expect(created.toString(), isNot(contains(created.temporaryPassword)));
      },
    );

    test('correo ya en uso: no toca ninguna cuenta ni el contador', () async {
      provisioner.existingEmails.add('nora@example.com');
      final before = Map.of(store.profiles);

      await expectLater(
        build().createAdministrator(_newAdmin),
        failure(AdministratorsFailureType.emailInUse),
      );

      expect(store.profiles, before);
      expect(store.registryCount, 2);
      expect(provisioner.accounts, isEmpty);
    });

    test(
      'si falla la escritura del perfil revierte el usuario y lo cierra',
      () async {
        store.failNextCommit = const AdministratorsRepositoryException(
          AdministratorsFailureType.network,
          'sin red',
        );

        await expectLater(
          build().createAdministrator(_newAdmin),
          failure(AdministratorsFailureType.network),
        );

        final account = provisioner.accounts.single;
        expect(account.rolledBack, isTrue);
        expect(account.closed, isTrue);
        expect(store.profiles.keys, unorderedEquals(['a', 'b']));
        expect(store.registryCount, 2);
      },
    );

    test('un fallo inesperado también revierte y no filtra detalles', () async {
      final broken = _ThrowingStore(store);
      final repository = FirestoreAdministratorsRepository(
        store: broken,
        provisioner: provisioner,
        currentUid: () => actor,
      );

      await expectLater(
        repository.createAdministrator(_newAdmin),
        throwsA(
          isA<AdministratorsRepositoryException>()
              .having((e) => e.type, 'type', AdministratorsFailureType.unknown)
              .having((e) => e.message, 'message', isNot(contains('secreto'))),
        ),
      );
      expect(provisioner.accounts.single.rolledBack, isTrue);
      expect(provisioner.accounts.single.closed, isTrue);
    });

    test('datos inválidos no crean ninguna cuenta', () async {
      final repository = build();
      for (final data in [
        const NewAdministratorData(
          firstNames: '',
          lastNames: 'Quintero',
          phoneCountryCodeId: 1,
          phoneNumber: '+573001112233',
          email: 'a@b.co',
        ),
        const NewAdministratorData(
          firstNames: 'Nora',
          lastNames: "' OR '1'='1' --",
          phoneCountryCodeId: 1,
          phoneNumber: '+573001112233',
          email: 'a@b.co',
        ),
        const NewAdministratorData(
          firstNames: 'Nora',
          lastNames: 'Quintero',
          phoneCountryCodeId: 1,
          phoneNumber: '+573001112233',
          email: 'no-es-correo',
        ),
        const NewAdministratorData(
          firstNames: 'Nora',
          lastNames: 'Quintero',
          phoneCountryCodeId: 0,
          phoneNumber: '+573001112233',
          email: 'a@b.co',
        ),
      ]) {
        await expectLater(
          repository.createAdministrator(data),
          failure(AdministratorsFailureType.invalidInput),
        );
      }
      expect(provisioner.accounts, isEmpty);
    });

    test('sin sesión no crea nada', () async {
      actor = null;
      await expectLater(
        build().createAdministrator(_newAdmin),
        failure(AdministratorsFailureType.permissionDenied),
      );
      expect(provisioner.accounts, isEmpty);
    });

    test(
      'si el registro no existe lo inicializa contando los activos',
      () async {
        store
          ..registryCount = null
          ..profiles['off'] = adminProfile(
            'off',
            status: AccountStatus.disabled,
          )
          ..profiles['pend'] = adminProfile('pend', mustChangePassword: true);

        await build().createAdministrator(_newAdmin);

        expect(store.ensureRegistryCalls, 1);
        // a, b y pend están activos (la contraseña pendiente cuenta): 3 + 1.
        expect(store.registryCount, 4);
      },
    );
  });

  group('actualizar administrador', () {
    const changes = AdministratorContactChanges(
      firstNames: ' Beto ',
      lastNames: 'Ríos',
      phoneCountryCodeId: 2,
      phoneNumber: '+541112223344',
    );

    test(
      'guarda contacto y recalcula fullName; no toca correo ni rol',
      () async {
        await build().updateAdministrator('b', changes);

        final stored = store.profiles['b']!;
        expect(stored.fullName, 'Beto Ríos');
        expect(stored.firstNames, 'Beto');
        expect(stored.phoneCountryCodeId, 2);
        expect(stored.email, 'b@example.com');
        expect(stored.role, RegisteredUserRole.admin);
        expect(stored.accountStatus, AccountStatus.active);
      },
    );

    test('una cuenta anonimizada o inexistente ya no existe', () async {
      store.profiles['gone'] = adminProfile(
        'gone',
        status: AccountStatus.anonymized,
      );
      final repository = build();
      await expectLater(
        repository.updateAdministrator('gone', changes),
        failure(AdministratorsFailureType.notFound),
      );
      await expectLater(
        repository.updateAdministrator('nadie', changes),
        failure(AdministratorsFailureType.notFound),
      );
    });

    test('datos inválidos no escriben', () async {
      await expectLater(
        build().updateAdministrator(
          'b',
          const AdministratorContactChanges(
            firstNames: 'B',
            lastNames: 'Ríos',
            phoneCountryCodeId: 1,
            phoneNumber: '+573001112233',
          ),
        ),
        failure(AdministratorsFailureType.invalidInput),
      );
      expect(store.profiles['b']!.firstNames, 'Admin');
    });
  });

  group('anonimizar y último administrador', () {
    test('anonimiza a otro: sin datos personales y resta 1', () async {
      await build().anonymizeAdministrator('b');

      final stored = store.profiles['b']!;
      expect(stored.accountStatus, AccountStatus.anonymized);
      expect(stored.fullName, 'Administrador eliminado');
      expect(stored.email, isEmpty);
      expect(stored.phoneNumber, isEmpty);
      expect(stored.firstNames, isNull);
      expect(store.registryCount, 1);
    });

    test('el último administrador activo no se puede anonimizar', () async {
      store.registryCount = 1;
      store.profiles.remove('b');

      await expectLater(
        build().anonymizeAdministrator('a'),
        failure(AdministratorsFailureType.lastAdmin),
      );
      await expectLater(
        build().anonymizeOwnAccount(),
        failure(AdministratorsFailureType.lastAdmin),
      );

      expect(store.profiles['a']!.accountStatus, AccountStatus.active);
      expect(store.profiles['a']!.email, 'a@example.com');
      expect(store.registryCount, 1);
    });

    test('un admin elimina su propia cuenta si queda otro activo', () async {
      await build().anonymizeOwnAccount();

      expect(store.profiles['a']!.accountStatus, AccountStatus.anonymized);
      expect(store.profiles['b']!.accountStatus, AccountStatus.active);
      expect(store.registryCount, 1);
    });

    test(
      'un admin con contraseña temporal pendiente cuenta como activo',
      () async {
        store
          ..profiles.remove('b')
          ..profiles['p'] = adminProfile('p', mustChangePassword: true)
          ..registryCount = 2;

        await build().anonymizeOwnAccount();

        expect(store.profiles['a']!.accountStatus, AccountStatus.anonymized);
        expect(store.profiles['p']!.accountStatus, AccountStatus.active);
        expect(store.registryCount, 1);
      },
    );

    test(
      'dos eliminaciones simultáneas con dos activos: solo una se completa',
      () async {
        final first = FirestoreAdministratorsRepository(
          store: store,
          provisioner: provisioner,
          currentUid: () => 'a',
        );
        final second = FirestoreAdministratorsRepository(
          store: store,
          provisioner: provisioner,
          currentUid: () => 'b',
        );

        final results = await Future.wait([
          first.anonymizeOwnAccount().then(
            (_) => 'ok',
            onError: (_) => 'error',
          ),
          second.anonymizeOwnAccount().then(
            (_) => 'ok',
            onError: (_) => 'error',
          ),
        ]);

        expect(results..sort(), ['error', 'ok']);
        expect(store.registryCount, 1);
        final active = store.profiles.values
            .where((p) => p.accountStatus == AccountStatus.active)
            .length;
        expect(active, 1);
        expect(store.transactionAttempts, greaterThan(2)); // hubo un reintento
      },
    );

    test('el rechazo de la segunda eliminación es lastAdmin', () async {
      final a = FirestoreAdministratorsRepository(
        store: store,
        provisioner: provisioner,
        currentUid: () => 'a',
      );
      final b = FirestoreAdministratorsRepository(
        store: store,
        provisioner: provisioner,
        currentUid: () => 'b',
      );
      final errors = <Object>[];
      await Future.wait([
        a.anonymizeAdministrator('b').catchError(errors.add),
        b.anonymizeAdministrator('a').catchError(errors.add),
      ]);

      expect(errors, hasLength(1));
      expect(
        (errors.single as AdministratorsRepositoryException).type,
        AdministratorsFailureType.lastAdmin,
      );
    });

    test(
      'anonimizar una cuenta ya anonimizada o inexistente es notFound',
      () async {
        store.profiles['gone'] = adminProfile(
          'gone',
          status: AccountStatus.anonymized,
        );
        final repository = build();
        await expectLater(
          repository.anonymizeAdministrator('gone'),
          failure(AdministratorsFailureType.notFound),
        );
        await expectLater(
          repository.anonymizeAdministrator('nadie'),
          failure(AdministratorsFailureType.notFound),
        );
        expect(store.registryCount, 2);
      },
    );

    test('anonimizar la propia cuenta ya anonimizada es idempotente', () async {
      store.profiles['a'] = adminProfile('a', status: AccountStatus.anonymized);

      await build().anonymizeOwnAccount();

      expect(store.registryCount, 2);
    });

    test('un no administrador no se anonimiza', () async {
      store.profiles['c1'] = adminProfile(
        'c1',
        role: RegisteredUserRole.client,
      );
      await expectLater(
        build().anonymizeAdministrator('c1'),
        failure(AdministratorsFailureType.notFound),
      );
    });

    test('si el registro no existe lo inicializa y respeta la regla', () async {
      store.registryCount = null;

      await build().anonymizeAdministrator('b');

      expect(store.ensureRegistryCalls, 1);
      expect(store.registryCount, 1);
    });

    test('con el registro ausente y un solo activo sigue rechazando', () async {
      store
        ..registryCount = null
        ..profiles.remove('b');

      await expectLater(
        build().anonymizeAdministrator('a'),
        failure(AdministratorsFailureType.lastAdmin),
      );
      expect(store.profiles['a']!.accountStatus, AccountStatus.active);
    });
  });

  test(
    'limpiar la marca actúa sobre la cuenta de quien tiene la sesión',
    () async {
      await build().clearMustChangePassword();
      expect(store.clearedMustChange, ['a']);
    },
  );
}

/// Store whose transaction fails with a non-repository error.
class _ThrowingStore extends FakeAdministratorsStore {
  _ThrowingStore(FakeAdministratorsStore base)
    : super(profiles: base.profiles.values) {
    registryCount = base.registryCount;
  }

  @override
  Future<T> runTransaction<T>(
    Future<T> Function(AdminTransaction tx) action,
  ) async => throw StateError('secreto-interno');
}
