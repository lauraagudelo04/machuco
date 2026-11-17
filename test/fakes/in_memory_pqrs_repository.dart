import 'package:machuco/database/repository/pqrs/pqrs_repository.dart';
import 'package:machuco/models/pqrs/pqrs.dart';

/// Fake [PqrsRepository] for tests: keeps everything in memory and lets a test
/// force a failure on the next call.
class InMemoryPqrsRepository implements PqrsRepository {
  InMemoryPqrsRepository({List<PqrsRequest> seed = const []})
    : requests = List.of(seed);

  final List<PqrsRequest> requests;
  final Map<String, PqrsSyncState> syncStates = {};

  int createCalls = 0;
  int appendTraceCalls = 0;
  int retryPendingCalls = 0;
  int discardPendingCalls = 0;
  PqrsTraceAppend? lastAppend;

  /// When set, the next repository call throws it and clears it.
  PqrsFailure? failNext;

  void _maybeFail() {
    final failure = failNext;
    if (failure != null) {
      failNext = null;
      throw failure;
    }
  }

  PqrsRecord _record(PqrsRequest request) => PqrsRecord(
    request: request,
    sync: syncStates[request.id] ?? PqrsSyncState.synced,
  );

  @override
  Future<PqrsRecord> create(PqrsNewRequest newRequest) async {
    createCalls++;
    _maybeFail();
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
      attachments: newRequest.photos,
    );
    requests.insert(0, request);
    return _record(request);
  }

  @override
  Future<List<PqrsRecord>> listByClient(String clientId) async {
    _maybeFail();
    return [
      for (final r in requests)
        if (r.clientId == clientId) _record(r),
    ];
  }

  @override
  Future<List<PqrsRecord>> listByOwner(String ownerId) async {
    _maybeFail();
    return [
      for (final r in requests)
        if (r.ownerId == ownerId) _record(r),
    ];
  }

  @override
  Future<List<PqrsRecord>> listAll() async {
    _maybeFail();
    return [for (final r in requests) _record(r)];
  }

  @override
  Future<PqrsRecord?> getDetail(String requestId) async {
    _maybeFail();
    for (final r in requests) {
      if (r.id == requestId) return _record(r);
    }
    return null;
  }

  @override
  Future<List<PqrsAttachment>> getPhotos(String requestId) async {
    _maybeFail();
    final record = await getDetail(requestId);
    return record?.request.allAttachments ?? const [];
  }

  @override
  Future<PqrsRecord> appendTrace(PqrsTraceAppend action) async {
    appendTraceCalls++;
    _maybeFail();
    final index = requests.indexWhere((r) => r.id == action.requestId);
    if (index < 0) {
      throw const PqrsFailure(PqrsFailureKind.notFound, 'No existe');
    }
    lastAppend = action;
    final current = requests[index];
    final updated = current.copyWith(
      status: action.entry.statusChange,
      trace: [...current.trace, action.entry],
      resolvedAt: action.resolvedAt,
      clearResolvedAt: action.clearResolvedAt,
      closedBy: action.closedBy,
    );
    requests[index] = updated;
    return _record(updated);
  }

  @override
  Future<void> retryPending({String? requestId}) async {
    retryPendingCalls++;
    _maybeFail();
    if (requestId == null) {
      syncStates.clear();
    } else {
      syncStates.remove(requestId);
    }
  }

  @override
  Future<void> discardPending(String requestId) async {
    discardPendingCalls++;
    _maybeFail();
    syncStates.remove(requestId);
  }
}
