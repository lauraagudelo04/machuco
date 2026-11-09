import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:machuco/controllers/owner_management/owner_controller.dart';
import 'package:machuco/database/app_database.dart';
import 'package:machuco/database/repository/document_type/document_type_repository.dart';
import 'package:machuco/database/repository/owner/owner_repository.dart';
import 'package:machuco/models/auth/account_status.dart';
import 'package:machuco/models/auth/country_phone_code.dart';
import 'package:machuco/models/owner_management/document_type.dart';
import 'package:machuco/models/owner_management/owner.dart';
import 'package:machuco/models/owner_management/owner_status_filter.dart';
import 'package:machuco/repositories/owner/owner_cloud_repository.dart';
import 'package:machuco/service/owner/owner_preferences.dart';
import 'package:machuco/service/owner/owner_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory directory;
  late AppDatabase database;

  /// Crea un controlador aislado apuntando a la base temporal compartida.
  ///
  /// Varios controladores sobre la misma base simulan cierres y aperturas de
  /// sesión: lo que persiste es la base, no el estado en memoria.
  OwnerController buildController({
    OwnerPreferences? preferences,
    OwnerCloudRepository? cloudRepository,
    String? currentUserId = 'admin-1',
  }) {
    final controller = OwnerController(
      service: OwnerService(repository: OwnerRepository(database: database)),
      documentTypeRepository: DocumentTypeRepository(database: database),
      preferences: preferences,
      cloudRepository: cloudRepository,
      currentUserId: () => currentUserId,
    );
    // Cancela el temporizador de reintentos al terminar cada prueba.
    addTearDown(controller.dispose);
    return controller;
  }

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('machuco_owner_ctl_');
    database = await AppDatabaseProvider.open(
      name: '${directory.path}${Platform.pathSeparator}owners.db',
    );
    // Caché local equivalente a tres usuarios con role owner ya descargados.
    final repository = OwnerRepository(database: database);
    for (final owner in _localOwners) {
      await repository.insertSynchronized(owner);
    }
  });

  tearDown(() async {
    await database.close();
    await directory.delete(recursive: true);
  });

  test('init carga los propietarios de SQLite', () async {
    final controller = buildController();

    await controller.init();

    expect(controller.isLoading, isFalse);
    expect(controller.lastError, isNull);
    expect(controller.hasOwners, isTrue);
    expect(controller.owners, hasLength(3));
  });

  test(
    'loadCountryCodes usa la semilla de desarrollo sin repositorio',
    () async {
      final controller = buildController();

      await controller.loadCountryCodes();

      expect(controller.isLoadingCountryCodes, isFalse);
      expect(controller.countryCodesError, isNull);
      expect(controller.hasCountryCodes, isTrue);
      expect(controller.selectedCountryCode?.dialCode, '+57');
    },
  );

  test('loadDocumentTypes lee el maestro local en orden', () async {
    final controller = buildController();

    await controller.loadDocumentTypes();

    expect(controller.isLoadingDocumentTypes, isFalse);
    expect(controller.documentTypesError, isNull);
    expect(controller.documentTypes.map((type) => type.code), [
      'CC',
      'CE',
      'NIT',
      'PAS',
      'TI',
    ]);
  });

  test(
    'loadDocumentTypes(forceRefresh) actualiza el maestro desde Supabase',
    () async {
      const body = '''
[
  {"id":2,"code":"CE","name":"Cédula de extranjería",
   "pattern":"^\\\\d{6,12}\$","example":"345678","is_active":true,"sort_order":2}
]
''';
      final client = MockClient(
        (_) async => http.Response.bytes(utf8.encode(body), 200),
      );
      final controller = OwnerController(
        service: OwnerService(repository: OwnerRepository(database: database)),
        documentTypeRepository: DocumentTypeRepository(
          database: database,
          httpClient: client,
          supabaseUrl: 'https://example.supabase.co',
          apiKey: 'public-key',
        ),
      );

      await controller.loadDocumentTypes(forceRefresh: true);

      expect(controller.documentTypes, [DocumentType.foreignerCard]);
      expect(controller.documentTypesError, isNull);
    },
  );

  test('lastUsedCountryCode retoma el indicativo guardado', () async {
    SharedPreferences.setMockInitialValues({});
    final controller = buildController(preferences: OwnerPreferences());
    await controller.loadCountryCodes();

    expect(await controller.lastUsedCountryCode(), isNull);

    await controller.saveLastCountryCode(0);

    expect((await controller.lastUsedCountryCode())?.dialCode, '+57');
  });

  test('sin preferencias guardar el indicativo no falla', () async {
    final controller = buildController();
    await controller.loadCountryCodes();

    expect(await controller.lastUsedCountryCode(), isNull);
    await controller.saveLastCountryCode(0);
    expect(await controller.lastUsedCountryCode(), isNull);
  });

  test('validatePhone respeta la longitud del país seleccionado', () async {
    final controller = buildController();
    await controller.loadCountryCodes();

    // Colombia: 10 dígitos.
    expect(controller.validatePhone(''), isNotNull);
    expect(controller.validatePhone('3001234567'), isNull);
    expect(controller.validatePhone('300123'), isNotNull);

    // Un país con otra longitud, elegido a mano: 9 dígitos.
    controller.selectCountryCode(
      const CountryPhoneCode(
        id: 99,
        isoCode: 'ES',
        countryName: 'España',
        dialCode: '+34',
        phoneMinLength: 9,
        phoneMaxLength: 9,
      ),
    );

    expect(controller.validatePhone('612345678'), isNull);
    expect(controller.validatePhone('61234567'), isNotNull);
    expect(controller.validatePhone('6123456789'), isNotNull);
  });

  test(
    'un propietario creado sobrevive al cierre de sesión (nueva instancia)',
    () async {
      final firstSession = buildController(
        cloudRepository: _FakeOwnerCloudRepository(),
      );
      await firstSession.init();

      final created = await firstSession.createOwner(
        fullName: 'Camilo Torres',
        documentType: DocumentType.citizenshipCard,
        documentNumber: '79123456',
        email: 'camilo.torres@machuco.com',
        phone: '320 555 1234',
        countryCode: '+57',
        countryName: 'Colombia',
      );

      expect(created, isNotNull);
      expect(created!.owner.isSynchronized, isTrue);
      expect(created.owner.phoneWithDialCode, '+57 320 555 1234');
      expect(created.temporaryPassword, isNotEmpty);

      // Nueva instancia = sesión nueva: la memoria arranca vacía.
      final secondSession = buildController();
      expect(secondSession.owners, isEmpty);

      await secondSession.init();

      expect(
        secondSession.owners.any(
          (owner) =>
              owner.id == created.owner.id &&
              owner.documentNumber == '79123456' &&
              owner.phone == '320 555 1234' &&
              owner.countryCode == '+57',
        ),
        isTrue,
      );
      // Las 3 semillas originales más la creada.
      expect(secondSession.owners, hasLength(4));
    },
  );

  test('createOwner rechaza un correo inválido sin tocar la base', () async {
    final controller = buildController(
      cloudRepository: _FakeOwnerCloudRepository(),
    );
    await controller.init();
    final totalBefore = controller.owners.length;

    final created = await controller.createOwner(
      fullName: 'Correo Malo',
      documentType: DocumentType.citizenshipCard,
      documentNumber: '111111',
      email: 'no-es-un-correo',
      phone: '+57 300 000 0000',
    );

    expect(created, isNull);
    expect(controller.lastError, contains('correo'));
    expect(controller.owners, hasLength(totalBefore));
  });

  test('createOwner rechaza un documento duplicado', () async {
    final controller = buildController(
      cloudRepository: _FakeOwnerCloudRepository(),
    );
    await controller.init();
    final laura = controller.owners.first;

    final created = await controller.createOwner(
      fullName: 'Otro Laura',
      documentType: laura.documentType,
      documentNumber: laura.documentNumber,
      email: 'otro@machuco.com',
      phone: '+57 300 000 0001',
    );

    expect(created, isNull);
    expect(controller.lastError, contains('Ya existe'));
  });

  test('createOwner sin sesión explica que necesita conexión', () async {
    final controller = buildController();
    await controller.init();

    final created = await controller.createOwner(
      fullName: 'Sin Sesión',
      documentType: DocumentType.citizenshipCard,
      documentNumber: '55555555',
      email: 'sin.sesion@machuco.com',
      phone: '300 555 5555',
      countryCode: '+57',
      countryName: 'Colombia',
    );

    expect(created, isNull);
    expect(controller.lastError, contains('Inicia sesión'));
    expect(controller.owners, hasLength(3));
  });

  test('updateOwnerPhone persiste el cambio de teléfono', () async {
    final controller = buildController();
    await controller.init();
    final laura = controller.owners.first;

    final updated = await controller.updateOwnerPhone(
      laura.id,
      '311 999 8888',
      countryCode: '+57',
      countryName: 'Colombia',
    );

    expect(updated, isNotNull);
    expect(updated!.phone, '311 999 8888');
    expect(updated.phoneWithDialCode, '+57 311 999 8888');

    final reloaded = buildController();
    await reloaded.init();
    final persisted = reloaded.owners.firstWhere(
      (owner) => owner.id == laura.id,
    );
    expect(persisted.phone, '311 999 8888');
    expect(persisted.countryCode, '+57');
  });

  test('setActiveState alterna el estado y persiste', () async {
    final controller = buildController();
    await controller.init();
    final active = controller.owners.firstWhere((owner) => owner.isActive);

    final deactivated = await controller.setActiveState(
      active.id,
      isActive: false,
    );

    expect(deactivated!.isActive, isFalse);

    final reloaded = buildController();
    await reloaded.init();
    expect(
      reloaded.owners.firstWhere((owner) => owner.id == active.id).isActive,
      isFalse,
    );
  });

  test('deleteOwner elimina y la eliminación persiste', () async {
    final controller = buildController();
    await controller.init();
    final target = controller.owners.first;
    final totalBefore = controller.owners.length;

    final deleted = await controller.deleteOwner(target.id);

    expect(deleted, isNotNull);
    expect(controller.owners, hasLength(totalBefore - 1));
    expect(controller.owners.any((owner) => owner.id == target.id), isFalse);

    final reloaded = buildController();
    await reloaded.init();
    expect(reloaded.owners.any((owner) => owner.id == target.id), isFalse);
  });

  test('la búsqueda y el filtro no alteran el listado persistido', () async {
    final controller = buildController();
    await controller.init();

    controller.search('laura');
    expect(controller.visibleOwners, hasLength(1));

    // El filtro se aplica junto con la búsqueda: nadie es inactivo y "laura"
    // a la vez, así que no queda nada visible.
    controller.filterByStatus(OwnerStatusFilter.inactive);
    expect(controller.visibleOwners, isEmpty);

    controller.clearFilters();
    expect(controller.visibleOwners, controller.owners);
    expect(controller.owners, hasLength(3));
  });

  group('sincronización con Firestore', () {
    test('no reenvía propietarios que ya están sincronizados', () async {
      final cloud = _FakeOwnerCloudRepository();
      final controller = buildController(cloudRepository: cloud);

      await controller.init();

      expect(controller.syncWarningMessage, isNull);
      expect(cloud.remote, isEmpty);
      expect(controller.owners, hasLength(3));
      expect(controller.owners.every((owner) => owner.isSynchronized), isTrue);
    });

    test('init incorpora propietarios que solo existen en la nube', () async {
      final cloud = _FakeOwnerCloudRepository()
        ..remote['remote-1'] = remoteOwner(id: 'remote-1');
      final controller = buildController(cloudRepository: cloud);

      await controller.init();

      expect(controller.owners, hasLength(4));
      expect(
        controller.owners.any(
          (owner) => owner.id == 'remote-1' && owner.isSynchronized,
        ),
        isTrue,
      );
    });

    test('init trae el estado de la cuenta desde users', () async {
      final cloud = _FakeOwnerCloudRepository()
        ..remote['uid-pending'] = remoteOwner(
          id: 'uid-pending',
          isActive: false,
          accountStatus: AccountStatus.pendingApproval,
        );
      final controller = buildController(cloudRepository: cloud);

      await controller.init();

      final pending = controller.owners.firstWhere(
        (owner) => owner.id == 'uid-pending',
      );
      expect(pending.isPendingApproval, isTrue);
      expect(pending.isActive, isFalse);
    });

    test(
      'si la nube falla al editar conserva los locales y programa el reintento',
      () async {
        final cloud = _FakeOwnerCloudRepository()
          ..remote['uid-1'] = remoteOwner(id: 'uid-1');
        final controller = buildController(cloudRepository: cloud);
        await controller.init();
        cloud.failSave = true;

        final updated = await controller.updateOwnerPhone(
          'uid-1',
          '311 999 8888',
          countryCode: '+57',
          countryName: 'Colombia',
        );
        await controller.pendingSync;

        expect(updated, isNotNull);
        expect(controller.syncWarningMessage, isNotNull);
        expect(controller.isAutoRetrying, isTrue);
        expect(controller.autoRetryAttempt, 1);
        expect(cloud.remote['uid-1']!.phone, isNot('311 999 8888'));
      },
    );

    test('un error de permisos no programa reintentos automáticos', () async {
      final cloud = _FakeOwnerCloudRepository()
        ..remote['uid-1'] = remoteOwner(id: 'uid-1');
      final controller = buildController(cloudRepository: cloud);
      await controller.init();
      cloud.failSaveForbidden = true;

      await controller.updateOwnerPhone('uid-1', '311 999 8888');
      await controller.pendingSync;

      expect(controller.syncWarningMessage, isNotNull);
      expect(controller.isAutoRetrying, isFalse);
      expect(controller.autoRetryAttempt, 0);
    });

    test(
      'crear un propietario lo envía a la nube y muestra la clave',
      () async {
        final cloud = _FakeOwnerCloudRepository();
        final controller = buildController(cloudRepository: cloud);
        await controller.init();

        final created = await controller.createOwner(
          fullName: 'Camilo Torres',
          documentType: DocumentType.citizenshipCard,
          documentNumber: '79123456',
          email: 'camilo.torres@machuco.com',
          phone: '320 555 1234',
          countryCode: '+57',
          countryName: 'Colombia',
        );

        expect(created, isNotNull);
        expect(cloud.remote.containsKey(created!.owner.id), isTrue);
        expect(created.owner.id, startsWith('uid-'));
        expect(created.temporaryPassword, 'Temp-Pass-1234');
        final persisted = await OwnerRepository(
          database: database,
        ).findById(created.owner.id);
        expect(persisted!.isSynchronized, isTrue);
        expect(persisted.accountStatus, AccountStatus.active);
        // El borrador local no quedó guardado: solo los 3 de la caché y el
        // nuevo propietario.
        expect(controller.owners, hasLength(4));
      },
    );

    test('crear con un correo ya registrado no guarda nada', () async {
      final cloud = _FakeOwnerCloudRepository()
        ..remote['uid-existing'] = remoteOwner(
          id: 'uid-existing',
          documentNumber: '999999',
          email: 'repetido@machuco.com',
        );
      final controller = buildController(cloudRepository: cloud);
      await controller.init();

      final created = await controller.createOwner(
        fullName: 'Repetido',
        documentType: DocumentType.citizenshipCard,
        documentNumber: '123456789',
        email: 'repetido@machuco.com',
        phone: '300 111 2222',
        countryCode: '+57',
      );

      expect(created, isNull);
      expect(controller.lastError, contains('correo'));
      expect(
        controller.owners.any((owner) => owner.fullName == 'Repetido'),
        isFalse,
      );
    });

    test('editar un propietario actualiza el documento remoto', () async {
      final cloud = _FakeOwnerCloudRepository()
        ..remote['uid-1'] = remoteOwner(id: 'uid-1');
      final controller = buildController(cloudRepository: cloud);
      await controller.init();

      final updated = await controller.updateOwner(
        'uid-1',
        fullName: 'Laura Actualizada',
        documentType: DocumentType.passport,
        documentNumber: 'AV123456',
        phone: '300 111 2233',
        countryCode: '+57',
        countryName: 'Colombia',
        address: 'Calle 1',
      );
      await controller.pendingSync;

      expect(updated, isNotNull);
      expect(cloud.remote['uid-1']!.fullName, 'Laura Actualizada');
      expect(cloud.remote['uid-1']!.documentType, DocumentType.passport);
      expect(cloud.remote['uid-1']!.documentNumber, 'AV123456');
      expect(cloud.remote['uid-1']!.address, 'Calle 1');
    });

    test('cambiar el estado envía accountStatus a la nube', () async {
      final cloud = _FakeOwnerCloudRepository()
        ..remote['uid-1'] = remoteOwner(id: 'uid-1');
      final controller = buildController(cloudRepository: cloud);
      await controller.init();

      final updated = await controller.setActiveState('uid-1', isActive: false);
      await controller.pendingSync;

      expect(updated, isNotNull);
      expect(updated!.isActive, isFalse);
      expect(cloud.statusChanges['uid-1'], isFalse);
    });

    test('no se puede activar a mano una cuenta pendiente', () async {
      final cloud = _FakeOwnerCloudRepository()
        ..remote['uid-pending'] = remoteOwner(
          id: 'uid-pending',
          isActive: false,
          accountStatus: AccountStatus.pendingApproval,
        );
      final controller = buildController(cloudRepository: cloud);
      await controller.init();

      final updated = await controller.setActiveState(
        'uid-pending',
        isActive: true,
      );

      expect(updated, isNull);
      expect(controller.lastError, contains('pendiente'));
    });

    test('eliminar borra también el documento remoto', () async {
      final cloud = _FakeOwnerCloudRepository()
        ..remote['uid-1'] = remoteOwner(id: 'uid-1');
      final controller = buildController(cloudRepository: cloud);
      await controller.init();
      final totalBefore = controller.owners.length;

      final deleted = await controller.deleteOwner('uid-1');

      expect(deleted, isNotNull);
      expect(cloud.remote.containsKey('uid-1'), isFalse);
      expect(controller.owners, hasLength(totalBefore - 1));
      expect(controller.owners.any((owner) => owner.id == 'uid-1'), isFalse);
    });

    test(
      'si no hay conexión deja el borrado pendiente y oculta al propietario',
      () async {
        final cloud = _FakeOwnerCloudRepository()
          ..remote['uid-1'] = remoteOwner(id: 'uid-1');
        final controller = buildController(cloudRepository: cloud);
        await controller.init();
        cloud.failDelete = true;

        final deleted = await controller.deleteOwner('uid-1');

        expect(deleted, isNotNull);
        expect(controller.lastDeletionIsPending, isTrue);
        expect(controller.owners.any((owner) => owner.id == 'uid-1'), isFalse);
        expect(cloud.remote.containsKey('uid-1'), isTrue);
        expect(controller.isAutoRetrying, isTrue);
        expect(
          await OwnerRepository(database: database).findPendingDeletes(),
          hasLength(1),
        );
      },
    );

    test(
      'el reintento borra en Firestore los pendientes de eliminar',
      () async {
        final cloud = _FakeOwnerCloudRepository()
          ..remote['uid-1'] = remoteOwner(id: 'uid-1');
        final controller = buildController(cloudRepository: cloud);
        await controller.init();
        cloud.failDelete = true;
        await controller.deleteOwner('uid-1');

        cloud.failDelete = false;
        await controller.retrySynchronization();

        expect(cloud.remote.containsKey('uid-1'), isFalse);
        expect(controller.syncWarningMessage, isNull);
        expect(controller.isAutoRetrying, isFalse);
        expect(
          await OwnerRepository(database: database).findPendingDeletes(),
          isEmpty,
        );
      },
    );

    test('el pull remoto no resucita un borrado pendiente', () async {
      final cloud = _FakeOwnerCloudRepository()
        ..remote['uid-1'] = remoteOwner(id: 'uid-1');
      final controller = buildController(cloudRepository: cloud);
      await controller.init();
      final target = controller.owners.firstWhere(
        (owner) => owner.id == 'uid-1',
      );
      cloud.failDelete = true;
      await controller.deleteOwner('uid-1');

      final repository = OwnerRepository(database: database);
      await repository.mergeRemoteOwners([target]);

      expect(
        (await repository.findAll()).any((owner) => owner.id == 'uid-1'),
        isFalse,
      );
    });
  });
}

/// Caché local de tres usuarios con `role = owner` ya sincronizados.
const _localOwners = <Owner>[
  Owner(
    id: 'uid-local-1',
    fullName: 'Inversiones Machuco S.A.S.',
    documentType: DocumentType.taxId,
    documentNumber: '900123456-7',
    email: 'contacto@inversionesmachuco.com',
    phone: '604 444 5566',
    countryCode: '+57',
    countryName: 'Colombia',
    address: 'Carrera 50 # 12-80, Rionegro',
    accountStatus: AccountStatus.active,
    isSynchronized: true,
  ),
  Owner(
    id: 'uid-local-2',
    fullName: 'Laura Gómez Restrepo',
    documentType: DocumentType.citizenshipCard,
    documentNumber: '1020304050',
    email: 'laura.gomez@machuco.com',
    phone: '300 123 4567',
    countryCode: '+57',
    countryName: 'Colombia',
    address: 'Calle 10 # 43-25, Medellín',
    accountStatus: AccountStatus.active,
    isSynchronized: true,
  ),
  Owner(
    id: 'uid-local-3',
    fullName: 'Simón Restrepo Vélez',
    documentType: DocumentType.foreignerCard,
    documentNumber: '345678',
    email: 'simon.restrepo@machuco.com',
    phone: '311 987 6543',
    countryCode: '+57',
    countryName: 'Colombia',
    isActive: false,
    accountStatus: AccountStatus.disabled,
    isSynchronized: true,
  ),
];

/// Propietario que ya existe en `users/{uid}`, para los tests de sincronización.
Owner remoteOwner({
  required String id,
  String? email,
  String documentNumber = '1020304050',
  bool isActive = true,
  AccountStatus? accountStatus,
}) => Owner(
  id: id,
  fullName: 'Laura Gómez Restrepo',
  documentType: DocumentType.citizenshipCard,
  documentNumber: documentNumber,
  email: email ?? '$id@machuco.com',
  phone: '300 123 4567',
  countryCode: '+57',
  countryName: 'Colombia',
  address: 'Calle 10',
  isActive: isActive,
  accountStatus: accountStatus ?? AccountStatus.active,
  isSynchronized: true,
);

/// Doble en memoria de [OwnerCloudRepository] para los tests del controlador.
class _FakeOwnerCloudRepository implements OwnerCloudRepository {
  final Map<String, Owner> remote = {};

  /// Último estado enviado por [setOwnerStatus], por uid.
  final Map<String, bool> statusChanges = {};
  bool failSave = false;
  bool failSaveForbidden = false;
  bool failList = false;
  bool failDelete = false;
  bool failCreate = false;
  bool failCreateForbidden = false;
  String temporaryPassword = 'Temp-Pass-1234';
  int _created = 0;

  @override
  Future<CreatedOwner> createOwner({
    required String adminId,
    required Owner owner,
    required AccountStatus accountStatus,
    int? phoneCountryCodeId,
    String? companyName,
    int? planId,
  }) async {
    if (failCreateForbidden) {
      throw const OwnerCloudRepositoryException(
        OwnerCloudFailureType.permissionDenied,
        'Sin permisos.',
      );
    }
    if (failCreate) {
      throw const OwnerCloudRepositoryException(
        OwnerCloudFailureType.network,
        'Sin conexión.',
      );
    }
    if (remote.values.any((existing) => existing.email == owner.email)) {
      throw const OwnerCloudRepositoryException(
        OwnerCloudFailureType.emailInUse,
        'Ese correo ya tiene una cuenta.',
      );
    }
    final created = owner
        .withId('uid-${++_created}')
        .copyWith(isSynchronized: true, accountStatus: accountStatus);
    remote[created.id] = created;
    return CreatedOwner(owner: created, temporaryPassword: temporaryPassword);
  }

  @override
  Future<void> updateOwner({
    required String adminId,
    required Owner owner,
    int? phoneCountryCodeId,
  }) async {
    if (failSaveForbidden) {
      throw const OwnerCloudRepositoryException(
        OwnerCloudFailureType.permissionDenied,
        'Sin permisos.',
      );
    }
    if (failSave) {
      throw const OwnerCloudRepositoryException(
        OwnerCloudFailureType.network,
        'Sin conexión.',
      );
    }
    remote[owner.id] = owner.copyWith(isSynchronized: true);
  }

  @override
  Future<void> setOwnerStatus({
    required String ownerId,
    required bool isActive,
  }) async {
    if (failSaveForbidden) {
      throw const OwnerCloudRepositoryException(
        OwnerCloudFailureType.permissionDenied,
        'Sin permisos.',
      );
    }
    if (failSave) {
      throw const OwnerCloudRepositoryException(
        OwnerCloudFailureType.network,
        'Sin conexión.',
      );
    }
    statusChanges[ownerId] = isActive;
    final existing = remote[ownerId];
    if (existing != null) {
      remote[ownerId] = existing.copyWith(
        isActive: isActive,
        accountStatus: isActive ? AccountStatus.active : AccountStatus.disabled,
      );
    }
  }

  @override
  Future<List<Owner>> listOwners() async {
    if (failList) {
      throw const OwnerCloudRepositoryException(
        OwnerCloudFailureType.network,
        'Sin conexión.',
      );
    }
    return remote.values.toList(growable: false);
  }

  @override
  Future<void> deleteOwner(String ownerId) async {
    if (failDelete) {
      throw const OwnerCloudRepositoryException(
        OwnerCloudFailureType.network,
        'Sin conexión.',
      );
    }
    remote.remove(ownerId);
  }
}
