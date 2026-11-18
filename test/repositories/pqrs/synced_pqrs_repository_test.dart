import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:machuco/database/app_database.dart';
import 'package:machuco/database/model/pqrs/pqrs_cache_mapper.dart';
import 'package:machuco/database/model/pqrs/pqrs_outbox_entry.dart';
import 'package:machuco/database/repository/pqrs/pqrs_repository.dart';
import 'package:machuco/database/repository/pqrs/synced_pqrs_repository.dart';
import 'package:machuco/models/pqrs/pqrs.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Remote double: stores what it receives, can be offline, can reject, and can
/// "lose the response" after applying a write.
class _FakeRemote implements PqrsRepository {
  final Map<String, PqrsRequest> requests = {};
  bool offline = false;
  PqrsFailure? rejectWith;
  bool loseNextResponse = false;
  int createCalls = 0;
  int appendCalls = 0;
  int concurrent = 0;
  int maxConcurrent = 0;

  static const _down = PqrsFailure(PqrsFailureKind.connection, 'sin red');

  void _gate() {
    if (offline) throw _down;
  }

  Future<void> _enter() async {
    concurrent++;
    if (concurrent > maxConcurrent) maxConcurrent = concurrent;
    await Future<void>.delayed(Duration.zero);
    concurrent--;
  }

  @override
  Future<PqrsRecord> create(PqrsNewRequest newRequest) async {
    createCalls++;
    await _enter();
    _gate();
    final rejection = rejectWith;
    if (rejection != null) throw rejection;
    final request = PqrsRequest(
      id: newRequest.id,
      motelId: newRequest.motelId,
      motelName: newRequest.motelName,
      clientId: newRequest.clientId,
      clientName: newRequest.clientName,
      ownerId: newRequest.ownerId,
      type: newRequest.type,
      subject: newRequest.subject,
      description: newRequest.description,
      createdAt: newRequest.createdAt,
    );
    requests[newRequest.id] = request;
    if (loseNextResponse) {
      loseNextResponse = false;
      throw _down;
    }
    return PqrsRecord(request: request);
  }

  @override
  Future<PqrsRecord> appendTrace(PqrsTraceAppend action) async {
    appendCalls++;
    await _enter();
    _gate();
    final rejection = rejectWith;
    if (rejection != null) throw rejection;
    final current = requests[action.requestId];
    if (current == null) {
      throw const PqrsFailure(PqrsFailureKind.notFound, 'no existe');
    }
    if (!current.trace.any((entry) => entry.id == action.entry.id)) {
      requests[action.requestId] = current.copyWith(
        trace: [...current.trace, action.entry],
        status: action.entry.statusChange,
      );
    }
    if (loseNextResponse) {
      loseNextResponse = false;
      throw _down;
    }
    return PqrsRecord(request: requests[action.requestId]!);
  }

  List<PqrsRecord> _where(bool Function(PqrsRequest) test) {
    _gate();
    return [
      for (final request in requests.values)
        if (test(request)) PqrsRecord(request: request),
    ];
  }

  @override
  Future<List<PqrsRecord>> listByClient(String clientId) async =>
      _where((request) => request.clientId == clientId);

  @override
  Future<List<PqrsRecord>> listByOwner(String ownerId) async =>
      _where((request) => request.ownerId == ownerId);

  @override
  Future<List<PqrsRecord>> listAll() async => _where((_) => true);

  @override
  Future<PqrsRecord?> getDetail(String requestId) async {
    _gate();
    final request = requests[requestId];
    return request == null ? null : PqrsRecord(request: request);
  }

  @override
  Future<List<PqrsAttachment>> getPhotos(String requestId) async {
    _gate();
    return const [];
  }

  @override
  Future<void> retryPending({String? requestId}) async {}

  @override
  Future<void> discardPending(String requestId) async {}
}

PqrsNewRequest _newRequest({
  String id = 'p-1',
  List<PqrsAttachment> photos = const [],
}) => PqrsNewRequest(
  id: id,
  motelId: 'motel-1',
  motelName: 'Motel Uno',
  clientId: 'client-1',
  clientName: 'Ana',
  ownerId: 'owner-1',
  type: PqrsType.queja,
  subject: 'Asunto',
  description: 'Descripción',
  createdAt: DateTime(2026, 1, 1, 10),
  photos: photos,
);

PqrsRequest _existing({
  String id = 'p-1',
  PqrsStatus status = PqrsStatus.pending,
}) => PqrsRequest(
  id: id,
  motelId: 'motel-1',
  motelName: 'Motel Uno',
  clientId: 'client-1',
  clientName: 'Ana',
  ownerId: 'owner-1',
  type: PqrsType.queja,
  subject: 'Asunto',
  description: 'Descripción',
  createdAt: DateTime(2026, 1, 1, 9),
  status: status,
);

PqrsTraceAppend _comment(
  String traceId, {
  String requestId = 'p-1',
  String message = 'Un comentario',
  PqrsActor author = PqrsActor.client,
  PqrsStatus? change,
  int minute = 0,
}) => PqrsTraceAppend(
  requestId: requestId,
  entry: PqrsTraceEntry(
    id: traceId,
    author: author,
    authorId: author == PqrsActor.client ? 'client-1' : 'owner-1',
    authorName: 'Autor',
    message: message,
    createdAt: DateTime(2026, 1, 1, 11, minute),
    statusChange: change,
  ),
);

void main() {
  late Directory directory;
  late AppDatabase database;
  late _FakeRemote remote;
  late SyncedPqrsRepository repository;

  setUpAll(() {
    sqfliteFfiInit();
    sqflite.databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('machuco_pqrs_sync_');
    database = await AppDatabaseProvider.open(
      name: '${directory.path}${Platform.pathSeparator}pqrs.db',
    );
    remote = _FakeRemote();
    repository = SyncedPqrsRepository(
      dao: database.pqrsDao,
      remote: remote,
      clock: () => DateTime(2026, 1, 1, 12),
    );
  });

  tearDown(() async {
    await database.close();
    await directory.delete(recursive: true);
  });

  /// Caches [request] by reading it online once, then goes offline.
  Future<void> cacheOnline(PqrsRequest request) async {
    remote.requests[request.id] = request;
    await repository.listByClient('client-1');
  }

  group('radicar', () {
    test(
      'sin red queda pending_sync, con sus fotos, y se ve en la lista',
      () async {
        remote.offline = true;
        final photo = PqrsAttachment(
          id: 'a',
          label: 'f',
          author: PqrsActor.client,
          capturedAt: DateTime(2026),
          seed: 0,
          bytes: Uint8List.fromList([1, 2, 3]),
          mimeType: 'image/png',
        );

        final record = await repository.create(_newRequest(photos: [photo]));

        expect(record.sync.isPending, isTrue);
        expect(record.request.status, PqrsStatus.pending);
        final rows = await database.pqrsDao.findOutbox();
        expect(rows, hasLength(1));
        expect(rows.single.id, 'p-1-open');
        expect(rows.single.syncStatus, PqrsOutboxStatus.pendingSync);
        expect(rows.single.attempts, 1, reason: 'cuenta el intento de red');
        final photos = await database.pqrsDao.findOutboxPhotos('p-1-open');
        expect(photos.single.id, 'p-1-open_1');

        final list = await repository.listByClient('client-1');
        expect(list.single.request.id, 'p-1');
        expect(list.single.sync.isPending, isTrue);
        expect(repository.notice, pqrsOfflineNotice);
      },
    );

    test('con red se confirma y la cola queda vacía', () async {
      final record = await repository.create(_newRequest());

      expect(record.sync.isSynced, isTrue);
      expect(remote.requests.keys, ['p-1']);
      expect(await database.pqrsDao.findOutbox(), isEmpty);
    });

    test('al volver la red no duplica aunque el envío se repita', () async {
      remote.offline = true;
      await repository.create(_newRequest());
      remote.offline = false;

      await Future.wait([repository.flush(), repository.flush()]);
      await repository.flush();

      expect(remote.requests, hasLength(1));
      expect(remote.createCalls, 1, reason: 'un solo envío');
      expect(remote.maxConcurrent, 1);
      expect(await database.pqrsDao.findOutbox(), isEmpty);
    });

    test('si la respuesta se perdió, el reintento no vuelve a crear', () async {
      remote.loseNextResponse = true;
      final record = await repository.create(_newRequest());
      expect(
        record.sync.isPending,
        isTrue,
        reason: 'llegó, pero sin confirmar',
      );
      expect(remote.createCalls, 1);

      await repository.flush();

      expect(remote.createCalls, 1, reason: 'detecta que ya llegó');
      expect(remote.requests, hasLength(1));
      expect(await database.pqrsDao.findOutbox(), isEmpty);
    });
  });

  group('acciones sin red', () {
    test('un comentario no cambia el estado visible', () async {
      await cacheOnline(_existing(status: PqrsStatus.inProgress));
      remote.offline = true;

      final record = await repository.appendTrace(_comment('t-1'));

      expect(record.request.status, PqrsStatus.inProgress);
      expect(record.request.trace.single.id, 't-1');
      expect(record.sync.isPending, isTrue);
    });

    test('un avance pendiente se aplica encima y se marca pendiente', () async {
      await cacheOnline(_existing(status: PqrsStatus.inProgress));
      remote.offline = true;

      final record = await repository.appendTrace(
        _comment(
          't-1',
          author: PqrsActor.owner,
          change: PqrsStatus.rejected,
          message: 'No procede',
        ),
      );

      expect(record.request.status, PqrsStatus.rejected);
      expect(record.sync.isPending, isTrue);
      expect(remote.requests['p-1']!.status, PqrsStatus.inProgress);
    });

    test('la caché de la lista conserva la PQRS sin red', () async {
      await cacheOnline(_existing());
      remote.offline = true;

      final list = await repository.listByClient('client-1');

      expect(list.single.request.id, 'p-1');
      expect(list.single.sync.isSynced, isTrue);
      expect(repository.notice, pqrsOfflineNotice);
    });

    test(
      'sin red y sin caché la lectura falla para poder reintentar',
      () async {
        remote.offline = true;

        await expectLater(
          repository.listByClient('client-1'),
          throwsA(
            isA<PqrsFailure>().having(
              (e) => e.isRetryable,
              'retryable',
              isTrue,
            ),
          ),
        );
      },
    );
  });

  group('rechazo y red', () {
    test('un fallo de red no pasa a failed', () async {
      await cacheOnline(_existing());
      remote.offline = true;

      await repository.appendTrace(_comment('t-1'));

      final row = (await database.pqrsDao.findOutbox()).single;
      expect(row.syncStatus, PqrsOutboxStatus.pendingSync);
      expect(row.errorMessage, isNull);
    });

    test(
      'el rechazo queda failed con motivo y bloquea las siguientes',
      () async {
        await cacheOnline(_existing(status: PqrsStatus.rejected));
        remote.rejectWith = const PqrsFailure(
          PqrsFailureKind.permission,
          'No tienes permiso',
        );

        final first = await repository.appendTrace(
          _comment('t-1', message: 'Mi texto'),
        );
        expect(first.sync.isFailed, isTrue);
        expect(
          first.sync.reason,
          'La solicitud cambió de estado mientras estabas sin conexión',
        );
        expect(first.request.status, PqrsStatus.rejected);

        remote.rejectWith = null;
        final second = await repository.appendTrace(
          _comment('t-2', message: 'Otro', minute: 5),
        );

        expect(remote.appendCalls, 1, reason: 't-2 espera a t-1');
        final rows = await database.pqrsDao.findOutbox();
        expect(rows.map((r) => r.syncStatus), [
          PqrsOutboxStatus.failed,
          PqrsOutboxStatus.pendingSync,
        ]);
        expect(rows.first.payload, contains('Mi texto'));
        expect(second.sync.isFailed, isTrue);
      },
    );

    test('otra PQRS no queda bloqueada por una fallida', () async {
      remote.requests['p-1'] = _existing();
      remote.requests['p-2'] = _existing(id: 'p-2');
      remote.rejectWith = const PqrsFailure(PqrsFailureKind.validation, 'no');
      await repository.appendTrace(_comment('t-1'));
      remote.rejectWith = null;

      await repository.appendTrace(_comment('t-9', requestId: 'p-2'));

      expect(remote.requests['p-2']!.trace.map((e) => e.id), ['t-9']);
    });

    test('una creación rechazada conserva el mensaje del servidor', () async {
      remote.rejectWith = const PqrsFailure(
        PqrsFailureKind.validation,
        'El motel ya no está disponible',
      );

      final record = await repository.create(_newRequest());

      expect(record.sync.reason, 'El motel ya no está disponible');
    });
  });

  group('Firestore manda', () {
    test('la lectura remota reemplaza la caché', () async {
      await cacheOnline(_existing(status: PqrsStatus.pending));
      remote.requests['p-1'] = _existing(status: PqrsStatus.resolved);

      final list = await repository.listByClient('client-1');

      expect(list.single.request.status, PqrsStatus.resolved);
      final cached = await database.pqrsDao.findCachedById('p-1');
      expect(PqrsCacheMapper.toRequest(cached!).status, PqrsStatus.resolved);
      expect(repository.notice, isNull);
    });

    test('el detalle remoto reemplaza las trazas cacheadas', () async {
      remote.requests['p-1'] = _existing().copyWith(
        trace: [_comment('t-1').entry],
      );
      await repository.getDetail('p-1');
      remote.requests['p-1'] = _existing();
      remote.offline = false;

      final record = await repository.getDetail('p-1');

      expect(record!.request.trace, isEmpty);
      expect(await database.pqrsDao.findCachedTraces('p-1'), isEmpty);
    });
  });

  group('reintentar y descartar', () {
    test('retryPending reenvía la acción fallida', () async {
      await cacheOnline(_existing());
      remote.rejectWith = const PqrsFailure(PqrsFailureKind.permission, 'no');
      await repository.appendTrace(_comment('t-1'));
      remote.rejectWith = null;

      await repository.retryPending(requestId: 'p-1');

      expect(remote.requests['p-1']!.trace.single.id, 't-1');
      expect(await database.pqrsDao.findOutbox(), isEmpty);
    });

    test('retryAction sin red avisa y deja la acción pendiente', () async {
      await cacheOnline(_existing());
      remote.rejectWith = const PqrsFailure(PqrsFailureKind.permission, 'no');
      await repository.appendTrace(_comment('t-1'));
      remote.rejectWith = null;
      remote.offline = true;

      await expectLater(
        repository.retryAction('t-1'),
        throwsA(isA<PqrsFailure>()),
      );

      final row = (await database.pqrsDao.findOutbox()).single;
      expect(row.syncStatus, PqrsOutboxStatus.pendingSync);
    });

    test('discardPending restaura la última versión sincronizada', () async {
      await cacheOnline(_existing(status: PqrsStatus.inProgress));
      remote.offline = true;
      await repository.appendTrace(
        _comment('t-1', author: PqrsActor.owner, change: PqrsStatus.resolved),
      );

      await repository.discardPending('p-1');
      final record = await repository.getDetail('p-1');

      expect(await database.pqrsDao.findOutbox(), isEmpty);
      expect(record!.request.status, PqrsStatus.inProgress);
      expect(record.request.trace, isEmpty);
      expect(record.sync.isSynced, isTrue);
    });

    test('discardAction de una creación quita la PQRS entera', () async {
      remote.offline = true;
      await repository.create(_newRequest());
      await repository.appendTrace(_comment('t-1'));

      await repository.discardAction('p-1-open');
      remote.offline = false;

      expect(await database.pqrsDao.findOutbox(), isEmpty);
      expect(await repository.getDetail('p-1'), isNull);
    });
  });
}
