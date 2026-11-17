// TODO(etapa-6): borrar este archivo junto con PqrsController.legacyShared.
// Repositorio en memoria temporal para que las vistas actuales sigan
// compilando y funcionando hasta que se compongan con el repositorio real.
import 'package:machuco/database/repository/pqrs/pqrs_repository.dart';
import 'package:machuco/models/pqrs/pqrs.dart';

class LegacyInMemoryPqrsRepository implements PqrsRepository {
  LegacyInMemoryPqrsRepository(List<PqrsRequest> seed)
    : _requests = List.of(seed);

  final List<PqrsRequest> _requests;

  PqrsRecord _record(PqrsRequest request) => PqrsRecord(request: request);

  @override
  Future<PqrsRecord> create(PqrsNewRequest newRequest) async {
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
    _requests.insert(0, request);
    return _record(request);
  }

  @override
  Future<List<PqrsRecord>> listByClient(String clientId) async => [
    for (final r in _requests)
      if (r.clientId == clientId) _record(r),
  ];

  @override
  Future<List<PqrsRecord>> listByOwner(String ownerId) async => [
    for (final r in _requests)
      if (r.ownerId == ownerId) _record(r),
  ];

  @override
  Future<List<PqrsRecord>> listAll() async => [
    for (final r in _requests) _record(r),
  ];

  @override
  Future<PqrsRecord?> getDetail(String requestId) async {
    for (final r in _requests) {
      if (r.id == requestId) return _record(r);
    }
    return null;
  }

  @override
  Future<List<PqrsAttachment>> getPhotos(String requestId) async {
    final record = await getDetail(requestId);
    return record?.request.allAttachments ?? const [];
  }

  @override
  Future<PqrsRecord> appendTrace(PqrsTraceAppend action) async {
    final index = _requests.indexWhere((r) => r.id == action.requestId);
    if (index < 0) {
      throw const PqrsFailure(
        PqrsFailureKind.notFound,
        'La solicitud ya no existe',
      );
    }
    final current = _requests[index];
    final updated = current.copyWith(
      status: action.entry.statusChange,
      trace: [...current.trace, action.entry],
      resolvedAt: action.resolvedAt,
      clearResolvedAt: action.clearResolvedAt,
      closedBy: action.closedBy,
    );
    _requests[index] = updated;
    return _record(updated);
  }

  @override
  Future<void> retryPending({String? requestId}) async {}

  @override
  Future<void> discardPending(String requestId) async {}
}
