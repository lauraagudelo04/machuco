import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:machuco/database/app_database.dart';
import 'package:machuco/database/model/pqrs/pqrs_cache_entry.dart';
import 'package:machuco/database/model/pqrs/pqrs_outbox_entry.dart';
import 'package:machuco/database/pqrs_migration.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _pqrsTables = [
  'pqrs_cache',
  'pqrs_trace_cache',
  'pqrs_outbox',
  'pqrs_outbox_photo',
  'allowed_image_formats',
  'pqrs_types',
];

PqrsCacheEntry _cache(String id, {String clientId = 'client-1', int at = 1}) =>
    PqrsCacheEntry(
      id: id,
      clientId: clientId,
      ownerId: 'owner-1',
      motelId: 'motel-1',
      motelName: 'Motel Uno',
      clientName: 'Ana',
      type: 'queja',
      subject: 'Asunto',
      description: 'Descripción',
      status: 'pending',
      photoCount: 0,
      createdAt: at,
      updatedAt: at,
    );

PqrsTraceCacheEntry _trace(String id, String pqrsId, int at) =>
    PqrsTraceCacheEntry(
      id: id,
      pqrsId: pqrsId,
      authorId: 'client-1',
      authorRole: 'client',
      message: 'Mensaje',
      photoCount: 0,
      createdAt: at,
    );

PqrsOutboxEntry _outbox(String id, {int at = 1}) => PqrsOutboxEntry(
  id: id,
  pqrsId: 'p-1',
  action: PqrsOutboxAction.comment,
  payload: '{}',
  syncStatus: PqrsOutboxStatus.pendingSync,
  createdAt: at,
);

PqrsOutboxPhotoEntry _photo(String id, String outboxId) => PqrsOutboxPhotoEntry(
  id: id,
  outboxId: outboxId,
  mimeType: 'image/png',
  bytes: Uint8List.fromList([1, 2, 3]),
);

void main() {
  late Directory directory;
  late String path;
  late AppDatabase database;

  sqflite.Database raw() => database.database as sqflite.Database;

  Future<bool> tableExists(String name) async => (await raw().rawQuery(
    "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
    [name],
  )).isNotEmpty;

  setUpAll(() {
    sqfliteFfiInit();
    sqflite.databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('machuco_pqrs_db_');
    path = '${directory.path}${Platform.pathSeparator}pqrs.db';
    database = await AppDatabaseProvider.open(name: path);
  });

  tearDown(() async {
    await database.close();
    await directory.delete(recursive: true);
  });

  group('migración de PQRS', () {
    test('las constantes apuntan a la versión actual de la base', () async {
      expect(pqrsMigrationToVersion, pqrsMigrationFromVersion + 1);
      expect(await raw().getVersion(), 24);
    });

    test('una instalación nueva trae las 6 tablas', () async {
      for (final table in _pqrsTables) {
        expect(await tableExists(table), isTrue, reason: table);
      }
    });

    test(
      'desde la versión anterior crea las 6 tablas y conserva datos',
      () async {
        for (final table in _pqrsTables.reversed) {
          await raw().execute('DROP TABLE $table');
        }
        await raw().setVersion(pqrsMigrationFromVersion);
        final owners = await raw().rawQuery(
          'SELECT COUNT(*) AS total FROM document_types',
        );
        final before = owners.single['total'];

        await database.close();
        database = await AppDatabaseProvider.open(name: path);

        expect(await raw().getVersion(), 24);
        for (final table in _pqrsTables) {
          expect(await tableExists(table), isTrue, reason: table);
        }
        final after = await raw().rawQuery(
          'SELECT COUNT(*) AS total FROM document_types',
        );
        expect(after.single['total'], before);
      },
    );

    test('es idempotente: repetirla no falla ni borra filas', () async {
      await database.pqrsDao.upsertAllCached([_cache('p-1')]);

      await createPqrsSchema(raw());
      await createPqrsSchema(raw());

      expect((await database.pqrsDao.findAllCached()).single.id, 'p-1');
    });
  });

  group('PqrsDao', () {
    test('replaceAll reemplaza caché y trazas y no toca la cola', () async {
      final dao = database.pqrsDao;
      await dao.enqueue(_outbox('t-1'), [_photo('t-1_1', 't-1')]);
      await dao.replaceAll(
        [_cache('p-1'), _cache('p-2')],
        [_trace('a', 'p-1', 1)],
      );

      await dao.replaceAll([_cache('p-3')], [_trace('b', 'p-3', 2)]);

      expect((await dao.findAllCached()).map((e) => e.id), ['p-3']);
      expect((await dao.findCachedTraces('p-1')), isEmpty);
      expect((await dao.findCachedTraces('p-3')).single.id, 'b');
      expect(await dao.findOutbox(), hasLength(1));
    });

    test('consulta por cliente y por propietario ordenada', () async {
      final dao = database.pqrsDao;
      await dao.upsertAllCached([
        _cache('p-1', at: 1),
        _cache('p-2', at: 3),
        _cache('p-3', clientId: 'client-2', at: 2),
      ]);

      expect((await dao.findCachedByClient('client-1')).map((e) => e.id), [
        'p-2',
        'p-1',
      ]);
      expect(await dao.findCachedByOwner('owner-1'), hasLength(3));
      expect((await dao.findCachedById('p-3'))?.clientId, 'client-2');
      expect(await dao.findCachedById('nope'), isNull);
    });

    test('replaceTracesOf solo cambia las trazas de esa PQRS', () async {
      final dao = database.pqrsDao;
      await dao.upsertAllTraces([_trace('a', 'p-1', 1), _trace('b', 'p-2', 1)]);

      await dao.replaceTracesOf('p-1', [_trace('c', 'p-1', 2)]);

      expect((await dao.findCachedTraces('p-1')).map((e) => e.id), ['c']);
      expect((await dao.findCachedTraces('p-2')).map((e) => e.id), ['b']);
    });

    test(
      'enqueue guarda la acción con una fila por foto y conserva los bytes',
      () async {
        final dao = database.pqrsDao;

        await dao.enqueue(_outbox('t-1'), [
          _photo('t-1_1', 't-1'),
          _photo('t-1_2', 't-1'),
        ]);

        final photos = await dao.findOutboxPhotos('t-1');
        expect(photos.map((e) => e.id), ['t-1_1', 't-1_2']);
        expect(photos.first.bytes, [1, 2, 3]);
        expect((await dao.findOutboxById('t-1'))?.attempts, 0);
      },
    );

    test('la cola sale en orden de creación y filtra por estado', () async {
      final dao = database.pqrsDao;
      await dao.enqueue(_outbox('b', at: 2), const []);
      await dao.enqueue(_outbox('a', at: 1), const []);
      await dao.markOutboxStatus('b', PqrsOutboxStatus.failed, 'Rechazada');

      expect((await dao.findOutbox()).map((e) => e.id), ['a', 'b']);
      final failed = await dao.findOutboxByStatus(PqrsOutboxStatus.failed);
      expect(failed.single.id, 'b');
      expect(failed.single.errorMessage, 'Rechazada');
      expect(failed.single.attempts, 1);
      expect(await dao.findOutboxOf('p-1'), hasLength(2));
    });

    test('un error de red cuenta el intento sin cambiar el estado', () async {
      final dao = database.pqrsDao;
      await dao.enqueue(_outbox('a'), const []);

      await dao.countOutboxAttempt('a');

      final entry = await dao.findOutboxById('a');
      expect(entry?.attempts, 1);
      expect(entry?.syncStatus, PqrsOutboxStatus.pendingSync);
    });

    test('reintentar vuelve a pendiente y borra el motivo', () async {
      final dao = database.pqrsDao;
      await dao.enqueue(_outbox('a'), const []);
      await dao.markOutboxStatus('a', PqrsOutboxStatus.failed, 'Rechazada');

      await dao.resetOutboxStatus('a', PqrsOutboxStatus.pendingSync);

      final entry = await dao.findOutboxById('a');
      expect(entry?.syncStatus, PqrsOutboxStatus.pendingSync);
      expect(entry?.errorMessage, isNull);
    });

    test('removeOutbox borra la acción y sus fotos', () async {
      final dao = database.pqrsDao;
      await dao.enqueue(_outbox('a'), [_photo('a_1', 'a')]);
      await dao.enqueue(_outbox('b'), [_photo('b_1', 'b')]);

      await dao.removeOutbox('a');

      expect(await dao.findOutboxById('a'), isNull);
      expect(await dao.findOutboxPhotos('a'), isEmpty);
      expect(await dao.findOutboxPhotos('b'), hasLength(1));
    });

    test('volver a encolar la misma acción reemplaza sus fotos', () async {
      final dao = database.pqrsDao;
      await dao.enqueue(_outbox('a'), [_photo('a_1', 'a'), _photo('a_2', 'a')]);

      await dao.enqueue(_outbox('a'), [_photo('a_1', 'a')]);

      expect(await dao.findOutbox(), hasLength(1));
      expect(await dao.findOutboxPhotos('a'), hasLength(1));
    });
  });

  group('DAOs de maestros', () {
    test(
      'allowed_image_formats y pqrs_types: replaceAll quita lo retirado',
      () async {
        final formats = database.allowedImageFormatDao;
        final types = database.pqrsTypeDao;
        await raw().insert('allowed_image_formats', {
          'id': 1,
          'mimeType': 'image/png',
          'extensions': '["png"]',
          'signatures': '[]',
          'maxSizeBytes': 100,
          'isActive': 1,
        });
        await raw().insert('pqrs_types', {
          'id': 1,
          'code': 'queja',
          'name': 'Queja',
          'description': 'x',
          'responseDays': 15,
          'allowsPhotos': 1,
          'sortOrder': 2,
          'isActive': 1,
        });

        await formats.replaceAll(const []);
        await types.replaceAll(const []);

        expect(await formats.findAll(), isEmpty);
        expect(await types.findAll(), isEmpty);
      },
    );
  });
}
