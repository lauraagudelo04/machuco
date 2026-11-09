import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:machuco/controllers/auth/administrators_controller.dart';
import 'package:machuco/database/repository/auth/administrators_repository.dart';
import 'package:machuco/models/auth/country_phone_code.dart';
import 'package:machuco/service/auth/auth_service.dart';
import 'package:machuco/service/auth/password_change_service.dart';

import '../../repositories/auth/administrators_test_support.dart';

const _colombia = CountryPhoneCode(
  id: 1,
  isoCode: 'CO',
  countryName: 'Colombia',
  dialCode: '+57',
  phoneMinLength: 10,
  phoneMaxLength: 10,
);

void main() {
  late FakeAdministratorsRepository repository;
  late _FakePasswordService passwords;
  late AdministratorsController controller;

  setUp(() {
    repository = FakeAdministratorsRepository()
      ..admins = [adminProfile('me'), adminProfile('other')];
    passwords = _FakePasswordService();
    controller = AdministratorsController(
      repository: repository,
      passwordChangeService: passwords,
      currentUid: () => 'me',
    );
  });

  Future<CreatedAdministrator?> create({
    String firstNames = 'Nora',
    String lastNames = 'Quintero',
    String phone = '300 111 2233',
    String email = 'nora@example.com',
  }) => controller.create(
    firstNames: firstNames,
    lastNames: lastNames,
    phoneCode: _colombia,
    phoneNumber: phone,
    email: email,
  );

  group('carga', () {
    test('carga la lista y avisa del estado de carga', () async {
      final states = <bool>[];
      controller.addListener(() => states.add(controller.isLoading));

      await controller.load();

      expect(controller.administrators.map((a) => a.uid), ['me', 'other']);
      expect(controller.error, isNull);
      expect(states, [true, false]);
      expect(controller.findAdministrator('other')?.uid, 'other');
    });

    test(
      'un error de red no deja datos parciales y permite reintentar',
      () async {
        await controller.load();
        repository.failList = const AdministratorsRepositoryException(
          AdministratorsFailureType.network,
          'No hay conexión.',
        );

        await controller.load();

        expect(controller.administrators, isEmpty);
        expect(controller.error, 'No hay conexión.');
        expect(controller.errorType, AdministratorsFailureType.network);

        repository.failList = null;
        await controller.load();
        expect(controller.administrators, hasLength(2));
        expect(controller.error, isNull);
      },
    );
  });

  group('crear', () {
    test('devuelve la contraseña temporal solo en el resultado', () async {
      final result = await create();

      expect(result, isNotNull);
      expect(result!.temporaryPassword, 'Temp-Password-1!');
      expect(repository.lastCreate?.phoneNumber, '+573001112233');
      expect(repository.lastCreate?.email, 'nora@example.com');
      expect(repository.lastCreate?.phoneCountryCodeId, 1);
      expect(controller.error, isNull);
      expect(controller.isSubmitting, isFalse);
      // La contraseña no queda en ningún estado del controller.
      expect(
        '${controller.error}${controller.errorType}',
        isNot(contains('Temp')),
      );
    });

    test('datos inválidos no llaman al repositorio', () async {
      for (final attempt in [
        () => create(firstNames: ''),
        () => create(lastNames: "'; DROP TABLE users; --"),
        () => create(phone: '123'),
        () => create(phone: '30011122ab'),
        () => create(email: 'sin-arroba'),
      ]) {
        expect(await attempt(), isNull);
        expect(controller.errorType, AdministratorsFailureType.invalidInput);
      }
      expect(repository.calls, isNot(contains('create')));
    });

    test('correo ya en uso se expone con su tipo', () async {
      repository.failNext = const AdministratorsRepositoryException(
        AdministratorsFailureType.emailInUse,
        'Ese correo ya está en uso.',
      );

      expect(await create(), isNull);

      expect(controller.errorType, AdministratorsFailureType.emailInUse);
      expect(controller.error, 'Ese correo ya está en uso.');
    });

    test('evita el doble envío', () async {
      final gate = Completer<void>();
      final slow = _SlowRepository(gate.future);
      controller = AdministratorsController(repository: slow);

      final first = create();
      final second = await create();
      gate.complete();
      await first;

      expect(second, isNull);
      expect(slow.createCalls, 1);
    });

    test('tras crear refresca la lista', () async {
      repository.admins = [adminProfile('me')];
      await create();
      expect(repository.calls, contains('list'));
    });
  });

  group('actualizar y eliminar', () {
    test('actualiza con celular con indicativo', () async {
      final ok = await controller.update(
        'other',
        firstNames: 'Beto',
        lastNames: 'Ríos',
        phoneCode: _colombia,
        phoneNumber: '3001112233',
      );

      expect(ok, isTrue);
      expect(repository.lastChanges?.phoneNumber, '+573001112233');
      expect(repository.lastChanges?.fullName, 'Beto Ríos');
    });

    test('actualizar con datos inválidos no llama al repositorio', () async {
      final ok = await controller.update(
        'other',
        firstNames: 'B',
        lastNames: 'Ríos',
        phoneCode: _colombia,
        phoneNumber: '3001112233',
      );
      expect(ok, isFalse);
      expect(repository.calls, isNot(contains('update:other')));
    });

    test('anonimiza a otro y lo quita de la lista', () async {
      await controller.load();

      final ok = await controller.anonymize('other');

      expect(ok, isTrue);
      expect(controller.administrators.map((a) => a.uid), ['me']);
    });

    test('último administrador: error lastAdmin y sin cambios', () async {
      await controller.load();
      repository.failNext = const AdministratorsRepositoryException(
        AdministratorsFailureType.lastAdmin,
        FirestoreAdministratorsRepository.lastAdminMessage,
      );

      expect(await controller.anonymize('other'), isFalse);

      expect(controller.errorType, AdministratorsFailureType.lastAdmin);
      expect(controller.administrators, hasLength(2));
    });

    test('no permite eliminar la propia cuenta por esta vía', () async {
      expect(await controller.anonymize('me'), isFalse);
      expect(repository.calls, isNot(contains('anonymize:me')));
      expect(controller.errorType, AdministratorsFailureType.invalidInput);
    });

    test(
      'una cuenta que ya no existe se informa y la lista se refresca',
      () async {
        await controller.load();
        repository.failNext = const AdministratorsRepositoryException(
          AdministratorsFailureType.notFound,
          'Esa cuenta de administrador ya no existe.',
        );
        repository.admins = [adminProfile('me')];

        expect(await controller.anonymize('other'), isFalse);

        expect(controller.errorType, AdministratorsFailureType.notFound);
        expect(controller.administrators.map((a) => a.uid), ['me']);
      },
    );

    test('evita el doble envío al eliminar', () async {
      final gate = Completer<void>();
      final slow = _SlowRepository(gate.future);
      controller = AdministratorsController(repository: slow);

      final first = controller.anonymize('other');
      final second = await controller.anonymize('other');
      gate.complete();
      await first;

      expect(second, isFalse);
      expect(slow.anonymizeCalls, 1);
    });
  });

  group('cambio de contraseña del primer ingreso', () {
    test('cambia la contraseña y limpia la marca', () async {
      final ok = await controller.changeOwnPassword(
        newPassword: 'Nueva-clave-segura1',
        confirmation: 'Nueva-clave-segura1',
      );

      expect(ok, isTrue);
      expect(passwords.changed, ['Nueva-clave-segura1']);
      expect(repository.calls, contains('clearMark'));
      expect(controller.passwordFailure, isNull);
    });

    test('contraseña débil o que no coincide no llama al servicio', () async {
      expect(
        await controller.changeOwnPassword(
          newPassword: 'corta',
          confirmation: 'corta',
        ),
        isFalse,
      );
      expect(
        await controller.changeOwnPassword(
          newPassword: 'Nueva-clave-segura1',
          confirmation: 'otra-distinta',
        ),
        isFalse,
      );
      expect(controller.passwordFailure, AuthFailureType.invalidInput);
      expect(passwords.changed, isEmpty);
    });

    test('weak-password del backend se expone', () async {
      passwords.failure = const AuthFailure(
        AuthFailureType.weakPassword,
        'La contraseña es demasiado débil.',
      );
      expect(
        await controller.changeOwnPassword(
          newPassword: 'Nueva-clave-segura1',
          confirmation: 'Nueva-clave-segura1',
        ),
        isFalse,
      );
      expect(controller.passwordFailure, AuthFailureType.weakPassword);
      expect(repository.calls, isNot(contains('clearMark')));
    });

    test('requires-recent-login se expone', () async {
      passwords.failure = const AuthFailure(
        AuthFailureType.requiresRecentLogin,
        'Inicia sesión de nuevo.',
      );
      await controller.changeOwnPassword(
        newPassword: 'Nueva-clave-segura1',
        confirmation: 'Nueva-clave-segura1',
      );
      expect(controller.passwordFailure, AuthFailureType.requiresRecentLogin);
    });

    test(
      'si falla limpiar la marca, el reintento no cambia la contraseña de nuevo',
      () async {
        repository.failClearMark = const AdministratorsRepositoryException(
          AdministratorsFailureType.network,
          'sin red',
        );
        expect(
          await controller.changeOwnPassword(
            newPassword: 'Nueva-clave-segura1',
            confirmation: 'Nueva-clave-segura1',
          ),
          isFalse,
        );
        expect(controller.passwordFailure, AuthFailureType.network);

        repository.failClearMark = null;
        expect(
          await controller.changeOwnPassword(
            newPassword: 'Nueva-clave-segura1',
            confirmation: 'Nueva-clave-segura1',
          ),
          isTrue,
        );
        expect(passwords.changed, hasLength(1));
      },
    );
  });
}

class _FakePasswordService implements PasswordChangeService {
  final changed = <String>[];
  AuthFailure? failure;

  @override
  Future<void> changePassword({required String newPassword}) async {
    final error = failure;
    if (error != null) throw error;
    changed.add(newPassword);
  }
}

class _SlowRepository extends FakeAdministratorsRepository {
  _SlowRepository(this._gate);

  final Future<void> _gate;
  int createCalls = 0;
  int anonymizeCalls = 0;

  @override
  Future<CreatedAdministrator> createAdministrator(
    NewAdministratorData data,
  ) async {
    createCalls++;
    await _gate;
    return super.createAdministrator(data);
  }

  @override
  Future<void> anonymizeAdministrator(String uid) async {
    anonymizeCalls++;
    await _gate;
  }
}
