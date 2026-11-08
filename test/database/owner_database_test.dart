import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:machuco/database/app_database.dart';
import 'package:machuco/database/repository/document_type/document_type_repository.dart';
import 'package:machuco/database/repository/owner/owner_repository.dart';
import 'package:machuco/models/owner_management/document_type.dart';
import 'package:machuco/models/owner_management/owner.dart';
import 'package:machuco/service/owner/owner_service.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

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
    String phone = '300 123 4567',
    String? countryCode = '+57',
    String? countryName = 'Colombia',
    String? address = 'Calle 10 # 43-25',
    bool isActive = true,
  }) => Owner(
    id: id,
    fullName: fullName,
    documentType: documentType,
    documentNumber: documentNumber,
    email: email,
    phone: phone,
    countryCode: countryCode,
    countryName: countryName,
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
    expect(loaded.countryCode, owner.countryCode);
    expect(loaded.countryName, owner.countryName);
    expect(loaded.phoneWithDialCode, '+57 300 123 4567');
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

  test(
    'existsByDocument detecta documentos duplicados por tipo y número',
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
    },
  );

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

    await repository.update(owner.copyWith(phone: '311 000 1111'));

    final updated = await repository.findById(owner.id);
    expect(updated!.phone, '311 000 1111');
    expect(updated.phoneWithDialCode, '+57 311 000 1111');
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

  test(
    'findUnsynchronized ignora los registros ya enviados a la nube',
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
      await repository.markSynchronized('owner-1');

      final pending = await repository.findUnsynchronized();
      expect(pending, hasLength(1));
      expect(pending.single.id, 'owner-2');
      expect(pending.single.isSynchronized, isFalse);
      expect((await repository.findById('owner-1'))!.isSynchronized, isTrue);
    },
  );

  test('mergeRemoteOwners inserta nuevos y respeta los pendientes', () async {
    // owner-1 sigue pendiente de envío; owner-2 ya fue confirmado.
    await repository.insert(buildOwner(phone: '300 000 0001'));
    await repository.insert(
      buildOwner(
        id: 'owner-2',
        fullName: 'Inversiones Machuco S.A.S.',
        documentType: DocumentType.taxId,
        documentNumber: '900123456-7',
        email: 'contacto@inversionesmachuco.com',
        phone: '300 000 0002',
      ),
    );
    await repository.markSynchronized('owner-2');

    await repository.mergeRemoteOwners([
      buildOwner(phone: '999 999 9999'),
      buildOwner(
        id: 'owner-2',
        fullName: 'Inversiones Machuco S.A.S.',
        documentType: DocumentType.taxId,
        documentNumber: '900123456-7',
        email: 'contacto@inversionesmachuco.com',
        phone: '999 999 9998',
      ),
      buildOwner(
        id: 'owner-3',
        fullName: 'Nuevo Remoto',
        documentNumber: '555555',
        email: 'remoto@machuco.com',
        phone: '999 999 9997',
      ),
    ]);

    // El pendiente local no se pisa.
    final localPending = await repository.findById('owner-1');
    expect(localPending!.phone, '300 000 0001');
    expect(localPending.isSynchronized, isFalse);

    // El ya sincronizado recibe los cambios de la nube.
    final synced = await repository.findById('owner-2');
    expect(synced!.phone, '999 999 9998');
    expect(synced.isSynchronized, isTrue);

    // El que solo existía en la nube se inserta ya marcado.
    final remoteOnly = await repository.findById('owner-3');
    expect(remoteOnly, isNotNull);
    expect(remoteOnly!.isSynchronized, isTrue);
    expect(await repository.findAll(), hasLength(3));
  });

  test(
    'el maestro de tipos de documento se siembra con los cinco códigos',
    () async {
      final types = await DocumentTypeRepository(
        database: database,
      ).findActive();

      expect(types.map((type) => type.code), ['CC', 'CE', 'NIT', 'PAS', 'TI']);
      expect(
        types.every((type) => type.acceptsDocumentNumber(type.example)),
        isTrue,
      );
    },
  );

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

  test(
    'el servicio registra un propietario que sobrevive a una nueva sesión',
    () async {
      final service = OwnerService(repository: repository);
      final created = await service.crearPropietario(
        fullName: 'Camilo Torres',
        documentType: DocumentType.citizenshipCard,
        documentNumber: '79123456',
        email: 'camilo.torres@machuco.com',
        phone: '320 555 1234',
        countryCode: '+57',
        countryName: 'Colombia',
      );

      // Nueva sesión = nuevo servicio y repositorio sobre la misma base.
      final secondSession = OwnerService(
        repository: OwnerRepository(database: database),
      );
      final loaded = await secondSession.cargarPropietarios();

      expect(
        loaded.any(
          (owner) => owner.id == created.id && owner.phone == created.phone,
        ),
        isTrue,
      );
    },
  );

  test(
    'la migración 13->14 agrega el indicativo sin perder los teléfonos',
    () async {
      final legacyPath = '${directory.path}${Platform.pathSeparator}legacy.db';
      sqfliteFfiInit();
      final legacy = await databaseFactoryFfi.openDatabase(
        legacyPath,
        options: sqflite.OpenDatabaseOptions(
          version: 13,
          onCreate: (db, version) async {
            await db.execute('''
            CREATE TABLE owners (
              id TEXT NOT NULL PRIMARY KEY,
              fullName TEXT NOT NULL,
              documentType TEXT NOT NULL,
              documentNumber TEXT NOT NULL,
              email TEXT NOT NULL,
              phone TEXT NOT NULL,
              address TEXT,
              isActive INTEGER NOT NULL,
              synchronized INTEGER NOT NULL,
              createdAt INTEGER NOT NULL,
              updatedAt INTEGER NOT NULL
            )
          ''');
          },
        ),
      );
      await legacy.insert('owners', {
        'id': 'owner-legacy',
        'fullName': 'Laura Gómez Restrepo',
        'documentType': DocumentType.citizenshipCard.name,
        'documentNumber': '1020304050',
        'email': 'laura.gomez@machuco.com',
        'phone': '+57 300 123 4567',
        'address': 'Calle 10 # 43-25',
        'isActive': 1,
        'synchronized': 0,
        'createdAt': 1,
        'updatedAt': 1,
      });
      await legacy.close();

      final migrated = await AppDatabaseProvider.open(name: legacyPath);
      addTearDown(migrated.close);
      final raw = migrated.database as sqflite.Database;

      expect(await raw.getVersion(), 15);
      final columns = await raw.rawQuery('PRAGMA table_info(owners)');
      expect(
        columns.map((column) => column['name']),
        containsAll(['countryCode', 'countryName']),
      );
      final rows = await raw.query('owners');
      expect(rows.single['phone'], '+57 300 123 4567');
      expect(rows.single['countryCode'], isNull);
      expect(await raw.query('document_types'), hasLength(5));
    },
  );
}
