import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:machuco/controllers/owner_management/owner_controller.dart';
import 'package:machuco/database/app_database.dart';
import 'package:machuco/database/repository/owner/owner_repository.dart';
import 'package:machuco/models/owner_management/document_type.dart';
import 'package:machuco/models/owner_management/owner_status_filter.dart';
import 'package:machuco/service/owner/owner_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory directory;
  late AppDatabase database;

  /// Crea un controlador aislado apuntando a la base temporal compartida.
  ///
  /// Varios controladores sobre la misma base simulan cierres y aperturas de
  /// sesión: lo que persiste es la base, no el estado en memoria.
  OwnerController buildController() => OwnerController(
    service: OwnerService(repository: OwnerRepository(database: database)),
  );

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('machuco_owner_ctl_');
    database = await AppDatabaseProvider.open(
      name: '${directory.path}${Platform.pathSeparator}owners.db',
    );
  });

  tearDown(() async {
    await database.close();
    await directory.delete(recursive: true);
  });

  test('init siembra los datos demo la primera vez', () async {
    final controller = buildController();

    await controller.init();

    expect(controller.isLoading, isFalse);
    expect(controller.lastError, isNull);
    expect(controller.hasOwners, isTrue);
    expect(controller.owners, hasLength(3));
  });

  test(
    'un propietario creado sobrevive al cierre de sesión (nueva instancia)',
    () async {
      final firstSession = buildController();
      await firstSession.init();

      final created = await firstSession.createOwner(
        fullName: 'Camilo Torres',
        documentType: DocumentType.citizenshipCard,
        documentNumber: '79123456',
        email: 'camilo.torres@machuco.com',
        phone: '+57 320 555 1234',
      );

      expect(created, isNotNull);

      // Nueva instancia = sesión nueva: la memoria arranca vacía.
      final secondSession = buildController();
      expect(secondSession.owners, isEmpty);

      await secondSession.init();

      expect(
        secondSession.owners.any(
          (owner) =>
              owner.documentNumber == '79123456' &&
              owner.phone == '+57 320 555 1234',
        ),
        isTrue,
      );
      // Las 3 semillas originales más la creada.
      expect(secondSession.owners, hasLength(4));
    },
  );

  test('createOwner rechaza un correo inválido sin tocar la base', () async {
    final controller = buildController();
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
    final controller = buildController();
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

  test('updateOwnerPhone persiste el cambio de teléfono', () async {
    final controller = buildController();
    await controller.init();
    final laura = controller.owners.first;

    final updated = await controller.updateOwnerPhone(
      laura.id,
      '+57 311 999 8888',
    );

    expect(updated, isNotNull);
    expect(updated!.phone, '+57 311 999 8888');

    final reloaded = buildController();
    await reloaded.init();
    expect(
      reloaded.owners.firstWhere((owner) => owner.id == laura.id).phone,
      '+57 311 999 8888',
    );
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
}
