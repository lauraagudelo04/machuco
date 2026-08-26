import 'package:flutter/foundation.dart';

import '../models/pqrs_models.dart';
import 'pqrs_mock_data.dart';

/// In-memory PQRS repository shared by the client, owner and system
/// administrator views.
///
/// It is a [ChangeNotifier] so the three views stay in sync with plain Flutter
/// state management: a widget listens with `ListenableBuilder` and rebuilds
/// whenever a request changes. There is no backend yet, so the data is seeded
/// from [pqrsMockRequests].
class PqrsStore extends ChangeNotifier {
  PqrsStore.seeded(List<PqrsRequest> requests) : _requests = List.of(requests);

  /// Shared instance used by the views while there is no dependency injection.
  static final PqrsStore instance = PqrsStore.seeded(pqrsMockRequests());

  final List<PqrsRequest> _requests;

  /// All requests, newest first.
  List<PqrsRequest> get all => List.unmodifiable(_requests);

  List<PqrsRequest> byMotel(String motelId) =>
      _requests.where((request) => request.motelId == motelId).toList();

  List<PqrsRequest> byClient(String clientId) =>
      _requests.where((request) => request.clientId == clientId).toList();

  PqrsRequest byId(String requestId) =>
      _requests.firstWhere((request) => request.id == requestId);

  /// Distinct motels present in the data, for the administrator selector.
  List<({String id, String name})> get motels {
    final seen = <String, String>{};
    for (final request in _requests) {
      seen[request.motelId] = request.motelName;
    }
    return [for (final entry in seen.entries) (id: entry.key, name: entry.value)];
  }

  /// Registers a new request opened by a client.
  PqrsRequest createRequest({
    required String motelId,
    required String motelName,
    required String clientId,
    required String clientName,
    required PqrsType type,
    required String subject,
    required String description,
    List<PqrsAttachment> attachments = const [],
  }) {
    final request = PqrsRequest(
      id: 'pqrs-${DateTime.now().microsecondsSinceEpoch}',
      motelId: motelId,
      motelName: motelName,
      clientId: clientId,
      clientName: clientName,
      type: type,
      subject: subject,
      description: description,
      createdAt: DateTime.now(),
      attachments: attachments,
    );
    _requests.insert(0, request);
    notifyListeners();
    return request;
  }

  /// Appends a comment with optional photos.
  ///
  /// The first owner answer moves a pending request to
  /// [PqrsStatus.inProgress]; a client comment never changes the status.
  void addUpdate({
    required String requestId,
    required PqrsActor author,
    required String message,
    List<PqrsAttachment> attachments = const [],
  }) {
    final request = _mutable(requestId);
    final movesToInProgress =
        author == PqrsActor.owner && request.status == PqrsStatus.pending;

    _append(
      request,
      PqrsTraceEntry(
        id: _entryId(),
        author: author,
        message: message,
        createdAt: DateTime.now(),
        attachments: attachments,
        statusChange: movesToInProgress ? PqrsStatus.inProgress : null,
      ),
      status: movesToInProgress ? PqrsStatus.inProgress : null,
    );
  }

  /// The owner proposes a solution and waits for the client to confirm it.
  void markResolved({
    required String requestId,
    required String message,
    List<PqrsAttachment> attachments = const [],
  }) {
    final request = _mutable(requestId);
    if (request.status == PqrsStatus.resolved) {
      throw StateError('La solicitud ${request.id} ya está marcada como solucionada.');
    }

    _append(
      request,
      PqrsTraceEntry(
        id: _entryId(),
        author: PqrsActor.owner,
        message: message,
        createdAt: DateTime.now(),
        attachments: attachments,
        statusChange: PqrsStatus.resolved,
      ),
      status: PqrsStatus.resolved,
    );
  }

  /// The owner rejects the request, stating the reason.
  void reject({required String requestId, required String message}) {
    final request = _mutable(requestId);
    _append(
      request,
      PqrsTraceEntry(
        id: _entryId(),
        author: PqrsActor.owner,
        message: message,
        createdAt: DateTime.now(),
        statusChange: PqrsStatus.rejected,
      ),
      status: PqrsStatus.rejected,
    );
  }

  /// The client confirms the solution and closes the request.
  ///
  /// Only the client closes a PQRS, and only after the owner proposed a
  /// solution.
  void closeByClient({required String requestId, required String message}) {
    final request = _mutable(requestId);
    if (!request.canBeClosedByClient) {
      throw StateError(
        'Solo se puede cerrar una solicitud solucionada; '
        'la solicitud ${request.id} está en estado ${request.status.label}.',
      );
    }

    _append(
      request,
      PqrsTraceEntry(
        id: _entryId(),
        author: PqrsActor.client,
        message: message,
        createdAt: DateTime.now(),
        statusChange: PqrsStatus.closed,
      ),
      status: PqrsStatus.closed,
    );
  }

  /// Returns the request only when it still accepts changes.
  PqrsRequest _mutable(String requestId) {
    final request = byId(requestId);
    if (request.status.isFinal) {
      throw StateError(
        'La solicitud ${request.id} está ${request.status.label.toLowerCase()} '
        'y no admite más actualizaciones.',
      );
    }
    return request;
  }

  void _append(PqrsRequest request, PqrsTraceEntry entry, {PqrsStatus? status}) {
    final index = _requests.indexWhere((item) => item.id == request.id);
    _requests[index] = request.copyWith(
      status: status,
      trace: [...request.trace, entry],
    );
    notifyListeners();
  }

  String _entryId() => 'trace-${DateTime.now().microsecondsSinceEpoch}';
}
