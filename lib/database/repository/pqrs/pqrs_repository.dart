import 'package:machuco/models/pqrs/pqrs.dart';

/// Local synchronization state of a PQRS (never stored in Firestore).
enum PqrsSyncStatus {
  /// Confirmed by the backend.
  synced,

  /// Saved locally, waiting to be sent.
  pendingSync,

  /// The backend rejected it or retries ran out; see [PqrsSyncState.reason].
  failed,
}

class PqrsSyncState {
  const PqrsSyncState._(this.status, this.reason);

  static const synced = PqrsSyncState._(PqrsSyncStatus.synced, null);
  static const pendingSync = PqrsSyncState._(PqrsSyncStatus.pendingSync, null);

  /// A failed state always carries a user-readable [reason].
  const PqrsSyncState.failed(String reason)
    : this._(PqrsSyncStatus.failed, reason);

  final PqrsSyncStatus status;
  final String? reason;

  bool get isSynced => status == PqrsSyncStatus.synced;
  bool get isPending => status == PqrsSyncStatus.pendingSync;
  bool get isFailed => status == PqrsSyncStatus.failed;
}

/// A request together with its local synchronization state.
class PqrsRecord {
  const PqrsRecord({required this.request, this.sync = PqrsSyncState.synced});

  final PqrsRequest request;
  final PqrsSyncState sync;
}

/// Data needed to open a request. The client comes from the session, never
/// from a form.
class PqrsNewRequest {
  const PqrsNewRequest({
    required this.id,
    required this.motelId,
    required this.motelName,
    required this.clientId,
    required this.clientName,
    required this.ownerId,
    required this.type,
    required this.subject,
    required this.description,
    required this.createdAt,
    this.photos = const [],
  });

  final String id;
  final String motelId;
  final String motelName;
  final String clientId;
  final String clientName;
  final String ownerId;
  final PqrsType type;
  final String subject;
  final String description;
  final DateTime createdAt;

  /// At most the configured photo limit; checked by the controller.
  final List<PqrsAttachment> photos;
}

/// One atomic change: a trace entry plus the optional status change it causes.
///
/// The implementation must apply [entry] and the status change together (one
/// `WriteBatch` in Firestore) so the parent document and its traces never
/// diverge. The new status is `entry.statusChange`; `null` keeps the status.
class PqrsTraceAppend {
  const PqrsTraceAppend({
    required this.requestId,
    required this.entry,
    this.resolvedAt,
    this.clearResolvedAt = false,
    this.closedBy,
  });

  final String requestId;
  final PqrsTraceEntry entry;

  /// Set when the request becomes resolved.
  final DateTime? resolvedAt;

  /// True when the request goes back to in progress (reopened).
  final bool clearResolvedAt;

  /// Set when the request becomes closed.
  final PqrsClosedBy? closedBy;
}

enum PqrsFailureKind { connection, validation, permission, notFound, unknown }

/// A classified, user-readable failure. Messages never carry sensitive data.
class PqrsFailure implements Exception {
  const PqrsFailure(this.kind, this.message);

  final PqrsFailureKind kind;
  final String message;

  /// Connection failures are the only ones worth retrying as they are.
  bool get isRetryable => kind == PqrsFailureKind.connection;

  @override
  String toString() => 'PqrsFailure(${kind.name}): $message';
}

/// Contract of the PQRS data source.
///
/// Not tied to any provider: Firestore, a local queue or an in-memory fake can
/// implement it. Every method throws [PqrsFailure] on error. The role and
/// ownership checks done by the controller only simulate the backend rules.
abstract class PqrsRepository {
  /// Creates the request with its photos.
  Future<PqrsRecord> create(PqrsNewRequest newRequest);

  /// Requests opened by [clientId], newest first.
  Future<List<PqrsRecord>> listByClient(String clientId);

  /// Requests of the motels owned by [ownerId], newest first.
  Future<List<PqrsRecord>> listByOwner(String ownerId);

  /// Every request, for the system administrator (read only).
  Future<List<PqrsRecord>> listAll();

  /// Request with its full trace, or `null` when it does not exist.
  Future<PqrsRecord?> getDetail(String requestId);

  /// Photos of a request (opening ones and those of the trace), loaded only
  /// when the detail needs them.
  Future<List<PqrsAttachment>> getPhotos(String requestId);

  /// Adds a trace entry and applies its status change in ONE atomic operation.
  Future<PqrsRecord> appendTrace(PqrsTraceAppend action);

  /// Retries sending what is pending or failed for [requestId], or for all
  /// requests when it is `null`.
  Future<void> retryPending({String? requestId});

  /// Drops the local pending or failed action of [requestId] and restores the
  /// last synchronized version.
  Future<void> discardPending(String requestId);
}
