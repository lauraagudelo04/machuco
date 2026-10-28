import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:machuco/database/app_database.dart';
import 'package:machuco/database/repository/owner/owner_repository.dart';
import 'package:machuco/models/owner_management/document_type.dart';
import 'package:machuco/models/owner_management/owner.dart';
import 'package:machuco/service/owner/owner_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory directory;
  late AppDatabase database;
  late OwnerRepository repository;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('machuco_owner_');
    database = await AppDatabaseProvider.open(
      name: '${directory.path}${Platform.pathSeparator}owners.db',
    );
    repository = OwnerRepository(database: database);
  });

  tearDown(() async {
    await database.close();
    await directory.delete(recursive: true);
  });

  Owner buildOwner({
    String id = 'owner-1',
    String fullName = 'Laura Gómez Restrepo',
    DocumentType documentType = DocumentType.citizenshipCard,
    String documentNumber = '1020304050',
    String email = 'laura.gomez@machuco.com',
    String phone = '+57 300 123 4567',
    String? address = 'Calle 10 # 43-25',
    bool isActive = true,
  }) => Owner(
    id: id,
    fullName: fullName,
    documentType: documentType,
    documentNumber: documentNumber,
    email: email,
    phone: phone,
    address: address,
    isActive: isActive,
  );

  test('inserta un propietario y lo recupera con todos sus campos', () async {
    final owner = buildOwner();
    await repository.insert(owner);

    final loaded = await repository.findById(owner.id);

    expect(loaded, isNotNull);
    expect(loaded!.id, owner.id);
    expect(loaded.fullName, owner.fullName);
    expect(loaded.documentType, owner.documentType);
    expect(loaded.documentNumber, owner.documentNumber);
    expect(loaded.email, owner.email);
    expect(loaded.phone, owner.phone);
    expect(loaded.address, owner.address);
    expect(loaded.isActive, isTrue);
  });

  test('findAll devuelve todos los propietarios', () async {
    await repository.insert(buildOwner());
    await repository.insert(
      buildOwner(
        id: 'owner-2',
        fullName: 'Inversiones Machuco S.A.S.',
        documentType: DocumentType.taxId,
        documentNumber: '900123456-7',
        email: 'contacto@machuco.com',
      ),
    );

    final all = await repository.findAll();

    expect(all, hasLength(2));
  });

  test('existsByDocument detecta documentos duplicados por tipo y número',
      () async {
    await repository.insert(buildOwner());

    expect(
      await repository.existsByDocument(
        DocumentType.citizenshipCard,
        '1020304050',
      ),
      isTrue,
    );
    expect(
      await repository.existsByDocument(DocumentType.taxId, '1020304050'),
      isFalse,
    );
    expect(
      await repository.existsByDocument(
        DocumentType.citizenshipCard,
        '999999',
      ),
      isFalse,
    );
  });

  test('update conserva createdAt y refleja el nuevo teléfono', () async {
    final owner = buildOwner();
    await repository.insert(owner);
    // createdAt vive en la fila, no en el modelo: se lee por SQL crudo.
    Future<Object?> readCreatedAt() async {
      final rows = await database.database.query(
        'owners',
        columns: ['createdAt'],
        where: 'id = ?',
        whereArgs: [owner.id],
      );
      return rows.single['createdAt'];
    }

    final originalCreatedAt = await readCreatedAt();

    await repository.update(owner.copyWith(phone: '+57 311 000 1111'));

    final updated = await repository.findById(owner.id);
    expect(updated!.phone, '+57 311 000 1111');
    expect(updated.isActive, isTrue);
    expect(await readCreatedAt(), originalCreatedAt);
  });

  test('deleteById elimina un propietario', () async {
    final owner = buildOwner();
    await repository.insert(owner);

    await repository.deleteById(owner.id);

    expect(await repository.findById(owner.id), isNull);
    expect(await repository.findAll(), isEmpty);
  });

  test('un propietario nuevo nace pendiente de sincronizar', () async {
    final owner = buildOwner();
    await repository.insert(owner);

    final loaded = await repository.findById(owner.id);
    expect(loaded!.isSynchronized, isFalse);

    // Escenario del feature: el campo 'sincronizado' queda en 0 en la fila.
    final rows = await database.database.query(
      'owners',
      columns: ['synchronized'],
      where: 'id = ?',
      whereArgs: [owner.id],
    );
    expect(rows.single['synchronized'], 0);
  });

  test('findUnsynchronized ignora los registros ya enviados a la nube',
      () async {
    await repository.insert(buildOwner());
    await repository.insert(
      buildOwner(
        id: 'owner-2',
        fullName: 'Inversiones Machuco S.A.S.',
        documentType: DocumentType.taxId,
        documentNumber: '900123456-7',
        email: 'contacto@inversionesmachuco.com',
      ),
    );

    expect(await repository.findUnsynchronized(), hasLength(2));

    // Simula que la nube confirmó el primero: solo ese sale de pendientes.
    await database.database.update(
      'owners',
      {'synchronized': 1},
      where: 'id = ?',
      whereArgs: ['owner-1'],
    );

    final pending = await repository.findUnsynchronized();
    expect(pending, hasLength(1));
    expect(pending.single.id, 'owner-2');
    expect(pending.single.isSynchronized, isFalse);
  });

  test('seedIfEmpty siembra la primera vez y no duplica después', () async {
    final seeds = buildSeedOwners();

    await repository.seedIfEmpty(seeds);
    await repository.seedIfEmpty(seeds);

    final all = await repository.findAll();
    expect(all, hasLength(seeds.length));
    // findAll ordena por nombre, no por orden de siembra: se compara como
    // conjunto para no acoplarse al orden alfabético.
    expect(
      all.map((owner) => owner.documentNumber).toSet(),
      seeds.map((owner) => owner.documentNumber).toSet(),
    );
  });

  test('seedIfEmpty no toca datos existentes', () async {
    await repository.insert(buildOwner());

    await repository.seedIfEmpty(buildSeedOwners());

    expect(await repository.findAll(), hasLength(1));
  });

  test('el servicio registra un propietario que sobrevive a una nueva sesión',
      () async {
    final service = OwnerService(repository: repository);
    final created = await service.crearPropietario(
      fullName: 'Camilo Torres',
      documentType: DocumentType.citizenshipCard,
      documentNumber: '79123456',
      email: 'camilo.torres@machuco.com',
      phone: '+57 320 555 1234',
    );

    // Nueva sesión = nuevo servicio y repositorio sobre la misma base.
    final secondSession = OwnerService(
      repository: OwnerRepository(database: database),
    );
    final loaded = await secondSession.cargarPropietarios();

    expect(
      loaded.any((owner) => owner.id == created.id && owner.phone == created.phone),
      isTrue,
    );
  });
}
