// Named parameters cannot be private, so the fields are set in the initializer.
// ignore_for_file: prefer_initializing_formals
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:machuco/database/model/pqrs/pqrs_cache_entry.dart';
import 'package:machuco/database/model/pqrs/pqrs_cache_mapper.dart';
import 'package:machuco/database/model/pqrs/pqrs_outbox_codec.dart';
import 'package:machuco/database/model/pqrs/pqrs_outbox_entry.dart';
import 'package:machuco/database/repository/pqrs/pqrs_dao.dart';
import 'package:machuco/database/repository/pqrs/pqrs_repository.dart';
import 'package:machuco/models/pqrs/pqrs.dart';

/// Notice shown when a read fell back to the local copy.
const pqrsOfflineNotice = 'Datos guardados, sin conexión';

const _conflictMessage =
    'La solicitud cambió de estado mientras estabas sin conexión';
const _unreadableActionMessage = 'La acción guardada ya no se puede leer';
const _localWriteMessage =
    'No se pudo guardar la solicitud en este dispositivo. Intenta de nuevo';
const _stillOfflineMessage =
    'Sigues sin conexión. Las acciones se enviarán cuando vuelva internet';

/// Lets a controller show the message of the last read without depending on a
/// concrete repository.
abstract interface class PqrsNoticeSource {
  /// [pqrsOfflineNotice] while the last read used the local copy; else `null`.
  String? get notice;
}

enum _SendResult { sent, offline, rejected, deferred }

/// [PqrsRepository] that keeps a SQLite copy and a SQLite queue over a remote
/// repository (Firestore in the app).
///
/// - Writes go FIRST to `pqrs_outbox` (with their photos) as `pending_sync`
///   and then a send is attempted. A network failure keeps the action
///   `pending_sync`; only a server rejection makes it `failed`, with a reason.
/// - Actions of one request are sent in creation order; while one is `failed`
///   the later ones of that request wait. Ids are fixed (trace id, photo ids),
///   and before sending, the remote is asked whether the action already
///   arrived, so a lost response never duplicates anything.
/// - Reads: the remote wins and replaces the cache; the queued actions are
///   applied on top (and marked pending). With no connection the cache is
///   returned with [notice] set; with no cache the error is raised so the
///   caller can retry.
/// - There is no connectivity package: sends are attempted when a screen reads,
///   on retry and after each write. Only one send runs at a time per instance.
///
/// The client-side checks of the controller only simulate `firestore.rules`.
class SyncedPqrsRepository implements PqrsRepository, PqrsNoticeSource {
  SyncedPqrsRepository({
    required PqrsDao dao,
    required PqrsRepository remote,
    String? Function()? currentUid,
    DateTime Function()? clock,
  }) : _dao = dao,
       _remote = remote,
       _currentUid = currentUid,
       _clock = clock ?? DateTime.now;

  final PqrsDao _dao;
  final PqrsRepository _remote;

  /// When given, only the actions written by that user are sent, and nothing
  /// is sent without a session. Tests may leave it `null`.
  final String? Function()? _currentUid;
  final DateTime Function() _clock;

  Future<bool>? _flushing;
  bool _flushAgain = false;
  int _lastStamp = 0;
  String? _notice;

  @override
  String? get notice => _notice;

  // ---------------------------------------------------------------- writes

  @override
  Future<PqrsRecord> create(PqrsNewRequest newRequest) async {
    final (entry, photos) = PqrsOutboxCodec.encodeCreate(
      newRequest,
      createdAt: _nextStamp(),
    );
    await _enqueue(entry, photos);
    final offline = await flush();
    final record = await _detail(newRequest.id, allowRemote: !offline);
    if (record == null) {
      throw const PqrsFailure(PqrsFailureKind.notFound, _localWriteMessage);
    }
    return record;
  }

  @override
  Future<PqrsRecord> appendTrace(PqrsTraceAppend action) async {
    final (entry, photos) = PqrsOutboxCodec.encodeAppend(
      action,
      createdAt: _nextStamp(),
    );
    await _enqueue(entry, photos);
    final offline = await flush();
    final record = await _detail(action.requestId, allowRemote: !offline);
    if (record == null) {
      throw const PqrsFailure(
        PqrsFailureKind.notFound,
        'La solicitud ya no existe',
      );
    }
    return record;
  }

  Future<void> _enqueue(
    PqrsOutboxEntry entry,
    List<PqrsOutboxPhotoEntry> photos,
  ) async {
    try {
      await _dao.enqueue(entry, photos);
    } on Object catch (error) {
      debugPrint('PQRS outbox: ${error.runtimeType}');
      throw const PqrsFailure(PqrsFailureKind.unknown, _localWriteMessage);
    }
  }

  /// Strictly increasing creation instant, so the queue order is never ambiguous.
  int _nextStamp() {
    final now = _clock().millisecondsSinceEpoch;
    _lastStamp = now > _lastStamp ? now : _lastStamp + 1;
    return _lastStamp;
  }

  // ------------------------------------------------------------------ flush

  /// Sends what is pending, once at a time: a call during a send joins it and
  /// makes it look at the queue again. Completes with `true` when the send
  /// stopped because there is no connection. Never throws.
  Future<bool> flush() {
    final running = _flushing;
    if (running != null) {
      _flushAgain = true;
      return running;
    }
    return _flushing = _flushLoop().whenComplete(() => _flushing = null);
  }

  Future<bool> _flushLoop() async {
    var offline = false;
    try {
      do {
        _flushAgain = false;
        offline = await _flushPass();
      } while (_flushAgain && !offline);
    } on Object catch (error) {
      debugPrint('PQRS flush: ${error.runtimeType}');
    }
    return offline;
  }

  /// One pass over the queue. Returns `true` when the connection is lost.
  Future<bool> _flushPass() async {
    final provider = _currentUid;
    final uid = provider?.call();
    if (provider != null && uid == null) return false;
    final blocked = <String>{};
    for (final row in await _dao.findOutbox()) {
      if (blocked.contains(row.pqrsId)) continue;
      if (row.syncStatus == PqrsOutboxStatus.failed) {
        blocked.add(row.pqrsId);
        continue;
      }
      if (uid != null && !_writtenBy(row, uid)) {
        // Someone else's action (another account used this device).
        blocked.add(row.pqrsId);
        continue;
      }
      switch (await _send(row)) {
        case _SendResult.sent:
          break;
        case _SendResult.offline:
          return true;
        case _SendResult.rejected || _SendResult.deferred:
          blocked.add(row.pqrsId);
      }
    }
    return false;
  }

  bool _writtenBy(PqrsOutboxEntry row, String uid) {
    try {
      return PqrsOutboxCodec.authorIdOf(row) == uid;
    } on FormatException {
      return true; // Sent so it fails with a readable reason.
    }
  }

  Future<_SendResult> _send(PqrsOutboxEntry row) async {
    try {
      final photos = await _dao.findOutboxPhotos(row.id);
      if (await _alreadyDelivered(row)) {
        await _dao.removeOutbox(row.id);
        return _SendResult.sent;
      }
      if (PqrsOutboxCodec.isCreate(row)) {
        await _remote.create(PqrsOutboxCodec.decodeCreate(row, photos));
      } else {
        await _remote.appendTrace(PqrsOutboxCodec.decodeAppend(row, photos));
      }
      await _dao.removeOutbox(row.id);
      return _SendResult.sent;
    } on FormatException {
      await _dao.markOutboxStatus(
        row.id,
        PqrsOutboxStatus.failed,
        _unreadableActionMessage,
      );
      return _SendResult.rejected;
    } on PqrsFailure catch (failure) {
      switch (failure.kind) {
        case PqrsFailureKind.connection:
          await _dao.countOutboxAttempt(row.id);
          return _SendResult.offline;
        case PqrsFailureKind.unknown:
          // Not a clear rejection: keep it pending, never lose the action.
          await _dao.countOutboxAttempt(row.id);
          return _SendResult.deferred;
        case PqrsFailureKind.permission ||
            PqrsFailureKind.validation ||
            PqrsFailureKind.notFound:
          await _dao.markOutboxStatus(
            row.id,
            PqrsOutboxStatus.failed,
            _reasonFor(row, failure),
          );
          return _SendResult.rejected;
      }
    }
  }

  /// A rejected trace action means the request moved on while the user was
  /// offline; a rejected creation keeps the message of the server.
  String _reasonFor(PqrsOutboxEntry row, PqrsFailure failure) {
    if (PqrsOutboxCodec.isCreate(row) ||
        failure.kind == PqrsFailureKind.notFound) {
      return failure.message;
    }
    return _conflictMessage;
  }

  /// True when the action already reached the remote (a previous response was
  /// lost). Failures other than the connection are ignored: for a request that
  /// does not exist yet the rules may deny the read, and then it is sent.
  Future<bool> _alreadyDelivered(PqrsOutboxEntry row) async {
    try {
      final record = await _remote.getDetail(row.pqrsId);
      if (record == null) return false;
      if (PqrsOutboxCodec.isCreate(row)) return true;
      return record.request.trace.any((entry) => entry.id == row.id);
    } on PqrsFailure catch (failure) {
      if (failure.kind == PqrsFailureKind.connection) rethrow;
      return false;
    }
  }

  /// Sends only when there is something in the queue; `true` means offline.
  Future<bool> _flushIfPending() async {
    try {
      if ((await _dao.findOutbox()).isEmpty) return false;
    } on Object catch (error) {
      debugPrint('PQRS outbox: ${error.runtimeType}');
      return false;
    }
    return flush();
  }

  // --------------------------------------------------------- queue controls

  @override
  Future<void> retryPending({String? requestId}) async {
    final rows = requestId == null
        ? await _dao.findOutboxByStatus(PqrsOutboxStatus.failed)
        : (await _dao.findOutboxOf(
            requestId,
          )).where((row) => row.syncStatus == PqrsOutboxStatus.failed);
    for (final row in rows) {
      await _dao.resetOutboxStatus(row.id, PqrsOutboxStatus.pendingSync);
    }
    await _retryFlush();
  }

  /// Retries one failed action (the one with trace id [actionId]).
  Future<void> retryAction(String actionId) async {
    final row = await _dao.findOutboxById(actionId);
    if (row == null) return;
    if (row.syncStatus == PqrsOutboxStatus.failed) {
      await _dao.resetOutboxStatus(row.id, PqrsOutboxStatus.pendingSync);
    }
    await _retryFlush();
  }

  Future<void> _retryFlush() async {
    final offline = await flush();
    if (offline) {
      throw const PqrsFailure(PqrsFailureKind.connection, _stillOfflineMessage);
    }
  }

  @override
  Future<void> discardPending(String requestId) async {
    for (final row in await _dao.findOutboxOf(requestId)) {
      await _dao.removeOutbox(row.id);
    }
  }

  /// Drops one action. Dropping a creation drops the whole request, because
  /// its later actions cannot exist without it.
  Future<void> discardAction(String actionId) async {
    final row = await _dao.findOutboxById(actionId);
    if (row == null) return;
    if (PqrsOutboxCodec.isCreate(row)) {
      await discardPending(row.pqrsId);
    } else {
      await _dao.removeOutbox(row.id);
    }
  }

  // ------------------------------------------------------------------ reads

  @override
  Future<List<PqrsRecord>> listByClient(String clientId) => _list(
    remoteRead: () => _remote.listByClient(clientId),
    cacheRead: () => _dao.findCachedByClient(clientId),
    createMatches: (request) => request.clientId == clientId,
  );

  @override
  Future<List<PqrsRecord>> listByOwner(String ownerId) => _list(
    remoteRead: () => _remote.listByOwner(ownerId),
    cacheRead: () => _dao.findCachedByOwner(ownerId),
    createMatches: (request) => request.ownerId == ownerId,
  );

  @override
  Future<List<PqrsRecord>> listAll() => _list(
    remoteRead: _remote.listAll,
    cacheRead: _dao.findAllCached,
    createMatches: (_) => true,
  );

  Future<List<PqrsRecord>> _list({
    required Future<List<PqrsRecord>> Function() remoteRead,
    required Future<List<PqrsCacheEntry>> Function() cacheRead,
    required bool Function(PqrsRequest created) createMatches,
  }) async {
    final offline = await _flushIfPending();
    List<PqrsRequest>? fresh;
    PqrsFailure? failure;
    if (offline) {
      failure = const PqrsFailure(
        PqrsFailureKind.connection,
        _stillOfflineMessage,
      );
    } else {
      try {
        fresh = [for (final record in await remoteRead()) record.request];
      } on PqrsFailure catch (error) {
        if (!error.isRetryable) rethrow;
        failure = error;
      }
    }

    final base = fresh ?? await _cachedRequests(cacheRead);
    if (fresh != null) await _storeList(fresh);
    final rows = await _safeOutbox();
    final byRequest = <String, List<PqrsOutboxEntry>>{};
    for (final row in rows) {
      byRequest.putIfAbsent(row.pqrsId, () => []).add(row);
    }

    final records = <PqrsRecord>[
      for (final request in base) _apply(request, byRequest[request.id] ?? []),
    ];
    final known = {for (final request in base) request.id};
    for (final entry in byRequest.entries) {
      if (known.contains(entry.key)) continue;
      final created = _createOf(entry.value);
      if (created == null || !createMatches(created)) continue;
      records.add(_apply(created, entry.value));
    }

    if (failure != null && records.isEmpty) throw failure;
    _notice = failure == null ? null : pqrsOfflineNotice;
    records.sort((a, b) => b.request.createdAt.compareTo(a.request.createdAt));
    return List.unmodifiable(records);
  }

  @override
  Future<PqrsRecord?> getDetail(String requestId) async {
    final offline = await _flushIfPending();
    return _detail(requestId, allowRemote: !offline);
  }

  Future<PqrsRecord?> _detail(
    String requestId, {
    required bool allowRemote,
  }) async {
    PqrsRequest? base;
    var fetched = false;
    PqrsFailure? failure;
    if (allowRemote) {
      try {
        base = (await _remote.getDetail(requestId))?.request;
        fetched = true;
        if (base != null) await _storeDetail(base);
      } on PqrsFailure catch (error) {
        if (!error.isRetryable) rethrow;
        failure = error;
      }
    } else {
      failure = const PqrsFailure(
        PqrsFailureKind.connection,
        _stillOfflineMessage,
      );
    }
    if (!fetched) base = await _cachedRequest(requestId);

    final rows = await _safeOutbox(requestId);
    base ??= _createOf(rows);
    if (base == null) {
      if (failure != null) throw failure;
      return null;
    }
    _notice = fetched ? null : pqrsOfflineNotice;
    return _apply(base, rows);
  }

  @override
  Future<List<PqrsAttachment>> getPhotos(String requestId) async {
    final local = <PqrsAttachment>[];
    try {
      for (final row in await _dao.findOutboxOf(requestId)) {
        final decoded = _decodePhotos(row, await _dao.findOutboxPhotos(row.id));
        local.addAll(decoded);
      }
    } on Object catch (error) {
      debugPrint('PQRS photos: ${error.runtimeType}');
    }
    try {
      final remote = await _remote.getPhotos(requestId);
      final sent = {for (final photo in remote) photo.id};
      return List.unmodifiable([
        ...remote,
        ...local.where((photo) => !sent.contains(photo.id)),
      ]);
    } on PqrsFailure catch (error) {
      if (!error.isRetryable) rethrow;
      if (local.isEmpty) rethrow;
      return List.unmodifiable(local);
    }
  }

  List<PqrsAttachment> _decodePhotos(
    PqrsOutboxEntry row,
    List<PqrsOutboxPhotoEntry> photos,
  ) {
    try {
      return PqrsOutboxCodec.isCreate(row)
          ? PqrsOutboxCodec.decodeCreate(row, photos).photos
          : PqrsOutboxCodec.decodeAppend(row, photos).entry.attachments;
    } on FormatException {
      return const [];
    }
  }

  // ---------------------------------------------------------------- overlay

  /// Applies the queued actions of one request on top of [base].
  ///
  /// Their trace entries are added (unless Firestore already has them). A
  /// pending action also moves the status, unless a `failed` action came
  /// before it. A failed action never changes the status, but its text stays
  /// visible. The sync state is failed, then pending, else synced.
  PqrsRecord _apply(PqrsRequest base, List<PqrsOutboxEntry> rows) {
    var request = base;
    var blocked = false;
    PqrsOutboxEntry? failedRow;
    for (final row in rows) {
      final failed = row.syncStatus == PqrsOutboxStatus.failed;
      if (failed) failedRow ??= row;
      if (PqrsOutboxCodec.isCreate(row)) {
        blocked = blocked || failed;
        continue;
      }
      final PqrsTraceAppend action;
      try {
        action = PqrsOutboxCodec.decodeAppend(row, const []);
      } on FormatException {
        blocked = true;
        continue;
      }
      if (request.trace.any((entry) => entry.id == row.id)) {
        blocked = blocked || failed;
        continue;
      }
      final change = action.entry.statusChange;
      final applyStatus = !failed && !blocked && change != null;
      request = request.copyWith(
        trace: [...request.trace, action.entry],
        status: applyStatus ? change : null,
        resolvedAt: applyStatus ? action.resolvedAt : null,
        clearResolvedAt: applyStatus && action.clearResolvedAt,
        closedBy: applyStatus ? action.closedBy : null,
      );
      blocked = blocked || failed;
    }
    final PqrsSyncState sync;
    if (failedRow != null) {
      sync = PqrsSyncState.failed(
        failedRow.errorMessage ?? _unreadableActionMessage,
      );
    } else if (rows.isNotEmpty) {
      sync = PqrsSyncState.pendingSync;
    } else {
      sync = PqrsSyncState.synced;
    }
    return PqrsRecord(request: request, sync: sync);
  }

  PqrsRequest? _createOf(List<PqrsOutboxEntry> rows) {
    for (final row in rows) {
      if (!PqrsOutboxCodec.isCreate(row)) continue;
      try {
        return PqrsOutboxCodec.requestOfCreate(row);
      } on FormatException {
        return null;
      }
    }
    return null;
  }

  Future<List<PqrsOutboxEntry>> _safeOutbox([String? requestId]) async {
    try {
      return requestId == null
          ? await _dao.findOutbox()
          : await _dao.findOutboxOf(requestId);
    } on Object catch (error) {
      debugPrint('PQRS outbox: ${error.runtimeType}');
      return const [];
    }
  }

  // ------------------------------------------------------------------ cache

  Future<List<PqrsRequest>> _cachedRequests(
    Future<List<PqrsCacheEntry>> Function() read,
  ) async {
    try {
      final requests = <PqrsRequest>[];
      for (final entry in await read()) {
        try {
          requests.add(PqrsCacheMapper.toRequest(entry));
        } on FormatException {
          continue; // A corrupt row is skipped, not fatal.
        }
      }
      return requests;
    } on Object catch (error) {
      debugPrint('PQRS cache: ${error.runtimeType}');
      return [];
    }
  }

  Future<PqrsRequest?> _cachedRequest(String requestId) async {
    try {
      final entry = await _dao.findCachedById(requestId);
      if (entry == null) return null;
      final traces = await _dao.findCachedTraces(requestId);
      return PqrsCacheMapper.toRequest(entry, traces: traces);
    } on Object catch (error) {
      debugPrint('PQRS cache: ${error.runtimeType}');
      return null;
    }
  }

  /// Replaces the cache with the last full read, keeping the traces of the
  /// requests that are still listed.
  Future<void> _storeList(List<PqrsRequest> requests) async {
    try {
      final traces = <PqrsTraceCacheEntry>[];
      for (final request in requests) {
        traces.addAll(await _dao.findCachedTraces(request.id));
      }
      await _dao.replaceAll(
        requests.map(PqrsCacheMapper.toEntry).toList(),
        traces,
      );
    } on Object catch (error) {
      debugPrint('PQRS cache: ${error.runtimeType}');
    }
  }

  Future<void> _storeDetail(PqrsRequest request) async {
    try {
      await _dao.upsertAllCached([PqrsCacheMapper.toEntry(request)]);
      await _dao.replaceTracesOf(request.id, [
        for (final trace in request.trace)
          PqrsCacheMapper.toTraceEntry(request.id, trace),
      ]);
    } on Object catch (error) {
      debugPrint('PQRS cache: ${error.runtimeType}');
    }
  }
}
