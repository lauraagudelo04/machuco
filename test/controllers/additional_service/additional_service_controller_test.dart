import 'package:flutter_test/flutter_test.dart';
import 'package:machuco/controllers/additional_service/system_admin_view/additional_service_system_administrator_controller.dart';
import 'package:machuco/database/repository/additional_service/additional_service_category_repository.dart';
import 'package:machuco/database/repository/additional_service/additional_service_cloud_repository.dart';
import 'package:machuco/database/repository/additional_service/additional_service_repository.dart';
import 'package:machuco/models/additional_service/additional_service.dart';
import 'package:machuco/models/additional_service/additional_service_category.dart';

class _FakeLocalRepository implements AdditionalServiceRepository {
  final Map<String, AdditionalService> rows = {};

  @override
  Future<List<AdditionalService>> findAll() async => rows.values.toList();

  @override
  Future<void> replaceForMotel(
    String motelId,
    List<AdditionalService> services,
  ) async {
    rows.removeWhere((_, service) => service.motelId == motelId);
    for (final service in services) {
      rows[service.id] = service;
    }
  }

  @override
  Future<void> insertService(AdditionalService service) async =>
      rows[service.id] = service;

  @override
  Future<void> updateService(AdditionalService service) async =>
      rows[service.id] = service;

  @override
  Future<void> deleteService(String serviceId) async => rows.remove(serviceId);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeCategoryRepository implements AdditionalServiceCategoryRepository {
  _FakeCategoryRepository({this.names = const [], this.failure});

  final List<String> names;
  final AdditionalServiceCategoryRepositoryException? failure;

  @override
  Future<List<AdditionalServiceCategory>> getCategories() async {
    if (failure != null) throw failure!;
    return [
      for (final name in names)
        AdditionalServiceCategory(name: name, createdAt: DateTime(2026)),
    ];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeCloudRepository implements AdditionalServiceCloudRepository {
  final Map<String, AdditionalService> remote = {};
  final Map<String, String> owners = {};
  AdditionalServiceCloudException? failure;

  void _check() {
    final error = failure;
    if (error != null) throw error;
  }

  @override
  Future<List<AdditionalService>> listByMotel(String motelId) async {
    _check();
    return remote.values.where((s) => s.motelId == motelId).toList();
  }

  @override
  Future<void> create({
    required String ownerId,
    required AdditionalService service,
  }) async {
    _check();
    remote[service.id] = service;
    owners[service.id] = ownerId;
  }

  @override
  Future<void> update(AdditionalService service) async {
    _check();
    remote[service.id] = service;
  }

  @override
  Future<void> delete(String serviceId) async {
    _check();
    remote.remove(serviceId);
  }
}

const _offline = AdditionalServiceCloudException(
  AdditionalServiceCloudFailureType.network,
  'Sin conexión con Firebase. Inténtalo de nuevo.',
);

const _sauna = AdditionalService(
  id: 's1',
  motelId: 'm1',
  name: 'Sauna',
  description: 'Sauna seco',
  category: 'Bienestar',
  price: 20000,
  active: true,
);

void main() {
  late _FakeLocalRepository local;
  late _FakeCloudRepository cloud;
  late String? uid;

  AdditionalServiceSystemAdministratorController build({
    _FakeCategoryRepository? categories,
  }) => AdditionalServiceSystemAdministratorController(
    motelId: 'm1',
    serviceRepository: local,
    categoryRepository: categories ?? _FakeCategoryRepository(),
    cloudRepository: cloud,
    currentUserId: () => uid,
  );

  setUp(() {
    local = _FakeLocalRepository();
    cloud = _FakeCloudRepository();
    uid = 'owner-1';
  });

  Future<bool> save(AdditionalServiceSystemAdministratorController c) =>
      c.saveAdditionalService(
        name: 'Jacuzzi',
        description: 'Jacuzzi privado',
        category: 'Bienestar',
        priceText: '30000',
      );

  test('crear guarda en Firestore con el uid actual y en lo local', () async {
    final controller = build();
    await controller.load();

    expect(await save(controller), isTrue);

    expect(cloud.remote, hasLength(1));
    expect(cloud.owners.values.single, 'owner-1');
    expect(local.rows, hasLength(1));
    expect(controller.services, hasLength(1));
    expect(controller.syncError, isNull);
  });

  test('sin sesión no guarda nada ni local ni en la nube', () async {
    uid = null;
    final controller = build();
    await controller.load();

    expect(await save(controller), isFalse);

    expect(cloud.remote, isEmpty);
    expect(local.rows, isEmpty);
    expect(controller.syncError, isNotNull);
  });

  test('si Firestore falla no deja la copia local adelantada', () async {
    final controller = build();
    await controller.load();
    cloud.failure = _offline;

    expect(await save(controller), isFalse);

    expect(local.rows, isEmpty);
    expect(controller.services, isEmpty);
    expect(controller.syncError, _offline.message);
  });

  test('load trae los servicios de la nube y refresca lo local', () async {
    cloud.remote['s1'] = _sauna;
    final controller = build();

    await controller.load();

    expect(controller.services.single.name, 'Sauna');
    expect(local.rows.keys, ['s1']);
  });

  test('load sin red conserva lo local y avisa del error', () async {
    local.rows['s1'] = _sauna;
    cloud.failure = _offline;
    final controller = build();

    await controller.load();

    expect(controller.services.single.name, 'Sauna');
    expect(controller.syncError, _offline.message);
  });

  test('activar y eliminar se reflejan en la nube y en lo local', () async {
    final controller = build();
    await controller.load();
    await save(controller);
    final id = controller.services.single.id;

    await controller.toggleAdditionalServiceActive(id);
    expect(cloud.remote[id]!.active, isFalse);
    expect(local.rows[id]!.active, isFalse);

    await controller.deleteAdditionalService(id);
    expect(cloud.remote, isEmpty);
    expect(local.rows, isEmpty);
  });

  test('si falla eliminar en la nube el servicio sigue visible', () async {
    final controller = build();
    await controller.load();
    await save(controller);
    final id = controller.services.single.id;
    cloud.failure = _offline;

    await controller.deleteAdditionalService(id);

    expect(controller.services, hasLength(1));
    expect(local.rows, hasLength(1));
    expect(controller.syncError, _offline.message);
  });

  test('las categorías se cargan aunque Firestore falle', () async {
    cloud.failure = _offline;
    final controller = build(
      categories: _FakeCategoryRepository(names: ['Bienestar', 'Estadía']),
    );

    await controller.load();

    expect(controller.categories, ['Bienestar', 'Estadía']);
    expect(controller.categoriesError, isNull);
    expect(controller.syncError, _offline.message);
  });

  test('si el maestro de categorías falla se explica el motivo', () async {
    final controller = build(
      categories: _FakeCategoryRepository(
        failure: const AdditionalServiceCategoryRepositoryException(
          'El catálogo de categorías no está configurado.',
        ),
      ),
    );

    await controller.load();

    expect(controller.categories, isEmpty);
    expect(
      controller.categoriesError,
      'El catálogo de categorías no está configurado.',
    );
  });
}
