import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:machuco/database/app_database.dart';
import 'package:machuco/database/model/motel/motel_entity.dart';
import 'package:machuco/database/repository/motel/motel_firestore_registry.dart';
import 'package:machuco/database/repository/motel/motel_repository.dart';
import 'package:machuco/database/repository/motel/motel_sql_connect_gateway.dart';
import 'package:machuco/database/repository/motel/sql_connect_motel_repository.dart';
import 'package:machuco/models/motel/motel_model.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Motel _motel(String id, {String ownerId = 'uid-1', bool available = true}) =>
    Motel(
      id: id,
      ownerId: ownerId,
      name: 'Motel $id',
      email: 'motel$id@test.com',
      roomCount: 4,
      nit: '90012345$id',
      address: 'Calle $id # 1-23',
      phone: '+57 3001234567',
      paymentMethods: const ['Efectivo'],
      imageUrls: const [],
      isAvailable: available,
    );

/// Doble del gateway: responde con datos fijos o lanza [error].
class _FakeGateway implements MotelSqlConnectGateway {
  List<Motel> all = [];
  List<Motel> mine = [];
  Object? error;
  int rowsUpdated = 1;
  Motel? lastCreatedForOwner;

  void _maybeThrow() {
    final e = error;
    if (e != null) throw e;
  }

  @override
  Future<List<Motel>> listAll() async {
    _maybeThrow();
    return all;
  }

  @override
  Future<List<Motel>> listMine() async {
    _maybeThrow();
    return mine;
  }

  @override
  Future<List<Motel>> listAvailable() async {
    _maybeThrow();
    return all.where((m) => m.isAvailable).toList();
  }

  @override
  Future<Motel?> getById(String id) async {
    _maybeThrow();
    for (final motel in all) {
      if (motel.id == id) return motel;
    }
    return null;
  }

  @override
  Future<String> createMine(Motel motel) async {
    _maybeThrow();
    return 'new-id';
  }

  @override
  Future<String> createForOwner(Motel motel) async {
    _maybeThrow();
    lastCreatedForOwner = motel;
    return 'admin-id';
  }

  @override
  Future<int> updateMine(Motel motel) async {
    _maybeThrow();
    return rowsUpdated;
  }

  @override
  Future<void> updateAsAdmin(Motel motel) async => _maybeThrow();

  @override
  Future<int> setMineAvailability(String id, bool isAvailable) async {
    _maybeThrow();
    return rowsUpdated;
  }
}

/// Doble de la copia en Firestore (`motels`).
class _FakeRegistry implements MotelFirestoreRegistry {
  final saved = <Motel>[];
  bool fail = false;

  @override
  Future<void> save(Motel motel) async {
    if (fail) throw Exception('firestore caído');
    saved.add(motel);
  }
}

void main() {
  late AppDatabase database;
  late Directory directory;
  late _FakeGateway gateway;
  late SqlConnectMotelRepository repository;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('machuco_sqlc_motel_');
    database = await AppDatabaseProvider.open(
      name: '${directory.path}${Platform.pathSeparator}motels.db',
    );
    gateway = _FakeGateway();
    repository = SqlConnectMotelRepository(
      gateway: gateway,
      daoProvider: () async => database.motelDao,
      currentUid: () => 'uid-1',
    );
  });

  tearDown(() async {
    await database.close();
    await directory.delete(recursive: true);
  });

  test('getMotels consulta SQL Connect y reemplaza la caché', () async {
    await database.motelDao.upsert(MotelEntity.fromModel(_motel('viejo')));
    gateway.all = [_motel('1'), _motel('2', ownerId: 'uid-2')];

    final motels = await repository.getMotels();

    expect(motels.map((m) => m.id), ['1', '2']);
    final cached = await database.motelDao.findAll();
    expect(cached.map((e) => e.id), containsAll(['1', '2']));
    expect(cached.map((e) => e.id), isNot(contains('viejo')));
  });

  test('getMyMotels sin red devuelve solo los del usuario en caché', () async {
    await database.motelDao.upsertAll([
      MotelEntity.fromModel(_motel('1')),
      MotelEntity.fromModel(_motel('2', ownerId: 'uid-2')),
    ]);
    gateway.error = Exception('sin red');

    final motels = await repository.getMyMotels();

    expect(motels.map((m) => m.id), ['1']);
  });

  test('lanza mensaje claro cuando no hay red ni caché', () {
    gateway.error = Exception('sin red');

    expect(
      repository.getMotels(),
      throwsA(
        isA<MotelRepositoryException>().having(
          (e) => e.message,
          'message',
          'No fue posible consultar los moteles',
        ),
      ),
    );
  });

  test('addMyMotel guarda el id del backend y el uid de la sesión', () async {
    final created = await repository.addMyMotel(
      _motel('', ownerId: 'owner-fijo'),
    );

    expect(created.id, 'new-id');
    expect(created.ownerId, 'uid-1');
    expect(await database.motelDao.findById('new-id'), isNotNull);
  });

  test('addMotelForOwner conserva el propietario elegido', () async {
    final created = await repository.addMotelForOwner(
      _motel('', ownerId: 'uid-9'),
    );

    expect(created.id, 'admin-id');
    expect(gateway.lastCreatedForOwner?.ownerId, 'uid-9');
  });

  test('traduce el NIT duplicado a un mensaje en español', () {
    gateway.error = Exception(
      'duplicate key value violates unique constraint "motels_nit_uidx"',
    );

    expect(
      repository.addMyMotel(_motel('')),
      throwsA(
        isA<MotelRepositoryException>().having(
          (e) => e.message,
          'message',
          'Ya existe un motel con ese NIT',
        ),
      ),
    );
  });

  test('updateMyMotel rechaza un motel que no es del usuario', () {
    gateway.rowsUpdated = 0;

    expect(
      repository.updateMyMotel(_motel('1', ownerId: 'uid-2')),
      throwsA(
        isA<MotelRepositoryException>().having(
          (e) => e.message,
          'message',
          'No puedes editar un motel que no es tuyo',
        ),
      ),
    );
  });

  test('setMyMotelAvailability actualiza la caché', () async {
    await database.motelDao.upsert(MotelEntity.fromModel(_motel('1')));

    await repository.setMyMotelAvailability('1', false);

    final cached = await database.motelDao.findById('1');
    expect(cached?.toModel().isAvailable, isFalse);
  });

  test('getMotelById sin red usa la caché', () async {
    await database.motelDao.upsert(MotelEntity.fromModel(_motel('1')));
    gateway.error = Exception('sin red');

    final motel = await repository.getMotelById('1');

    expect(motel?.id, '1');
  });

  group('copia en Firestore (motels)', () {
    late _FakeRegistry registry;

    setUp(() {
      registry = _FakeRegistry();
      repository = SqlConnectMotelRepository(
        gateway: gateway,
        daoProvider: () async => database.motelDao,
        currentUid: () => 'uid-1',
        firestoreRegistry: registry,
      );
    });

    test(
      'el propietario crea el motel y queda registrado con su uid',
      () async {
        await repository.addMyMotel(_motel('', ownerId: 'owner-fijo'));

        expect(registry.saved.single.id, 'new-id');
        expect(registry.saved.single.ownerId, 'uid-1');
      },
    );

    test('el administrador crea el motel para otro propietario', () async {
      await repository.addMotelForOwner(_motel('', ownerId: 'uid-9'));

      expect(registry.saved.single.id, 'admin-id');
      expect(registry.saved.single.ownerId, 'uid-9');
    });

    test('al cambiar la disponibilidad se actualiza el registro', () async {
      await database.motelDao.upsert(MotelEntity.fromModel(_motel('1')));

      await repository.setMyMotelAvailability('1', false);

      expect(registry.saved.single.isAvailable, isFalse);
    });

    test('si Firestore falla avisa que hay que reintentar', () {
      registry.fail = true;

      expect(
        repository.addMyMotel(_motel('')),
        throwsA(
          isA<MotelRepositoryException>().having(
            (e) => e.message,
            'message',
            contains('no se pudo registrar para las habitaciones'),
          ),
        ),
      );
    });
  });
}
