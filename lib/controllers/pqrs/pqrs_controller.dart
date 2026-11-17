// Named parameters cannot be private, so the fields are set in the initializer.
// ignore_for_file: prefer_initializing_formals
import 'package:flutter/foundation.dart';
import 'package:machuco/database/repository/pqrs/pqrs_repository.dart';
import 'package:machuco/models/pqrs/pqrs.dart';
import 'package:machuco/models/pqrs/pqrs_session.dart';
import 'package:machuco/repositories/pqrs/pqrs_repository_provider.dart';
import 'package:machuco/database/repository/pqrs/synced_pqrs_repository.dart';
import 'package:machuco/utils/pqrs_validator.dart';

/// Fixed message of the trace entry written when the owner closes a request
/// because the client did not answer in time.
const pqrsTimeoutClosureMessage =
    'Cerrada por vencimiento del plazo de confirmación';

/// Default message when the client confirms the solution without writing one.
const pqrsClientClosureMessage = 'Solución confirmada por el cliente';

const _loginRequiredMessage = 'Debes iniciar sesión';
const _noPermissionMessage = 'No tienes permiso para realizar esta acción';
const _notFoundMessage = 'La solicitud ya no existe';
const _finalMessage =
    'La solicitud está cerrada o rechazada y no admite más cambios';
const _unknownMessage = 'Ocurrió un error inesperado. Intenta de nuevo';

/// Lifecycle rules of the PQRS module over a [PqrsRepository].
///
/// A [ChangeNotifier]: views listen with `ListenableBuilder`. It keeps an
/// in-memory copy of the requests loaded from the repository and exposes
/// loading, error and empty states. Every advance is ONE atomic repository
/// call. The role checks here only simulate the Firestore rules (Stage 3).
class PqrsController extends ChangeNotifier {
  PqrsController({
    required PqrsRepository repository,
    required PqrsSession? session,
    required DateTime Function() clock,
    List<PqrsRequest> initialRequests = const [],
    int maxPhotos = PqrsValidator.defaultMaxPhotos,
  }) : _repository = repository,
       _session = session,
       _clock = clock,
       _maxPhotos = maxPhotos.clamp(1, PqrsValidator.hardMaxPhotos) {
    for (final request in initialRequests) {
      _requests.add(request);
    }
  }

  /// Builds the controller of the signed-in user with the composed
  /// repository.
  ///
  /// Throws [PqrsFailure]: `permission` without a usable session ("Debes
  /// iniciar sesión"), `connection` when the profile cannot be read and
  /// `unknown` when the repository was never composed.
  static Future<PqrsController> forCurrentUser() async {
    final repository = PqrsRepositoryProvider.instance;
    if (repository == null) {
      throw const PqrsFailure(PqrsFailureKind.unknown, _unknownMessage);
    }
    final PqrsSession? session;
    try {
      session = await PqrsRepositoryProvider.sessionResolver();
    } on Object catch (error) {
      debugPrint('PQRS: session ${error.runtimeType}');
      throw const PqrsFailure(
        PqrsFailureKind.connection,
        'No pudimos verificar tu sesión. Revisa tu conexión e intenta de nuevo',
      );
    }
    if (session == null) {
      throw const PqrsFailure(
        PqrsFailureKind.permission,
        _loginRequiredMessage,
      );
    }
    final settings = await PqrsRepositoryProvider.validation?.loadSettings();
    return PqrsController(
      repository: repository,
      session: session,
      clock: DateTime.now,
      maxPhotos: settings?.value.maxPhotos ?? PqrsValidator.defaultMaxPhotos,
    );
  }

  final PqrsRepository _repository;
  final DateTime Function() _clock;
  final PqrsSession? _session;
  final int _maxPhotos;

  final List<PqrsRequest> _requests = [];
  final Map<String, PqrsSyncState> _sync = {};

  bool _loading = false;
  bool _busy = false;
  bool _loaded = false;
  bool _disposed = false;
  int _sequence = 0;
  PqrsFailure? _error;
  PqrsRequest? _lastCreated;
  Future<bool> Function()? _retryAction;

  // ---------------------------------------------------------------- state

  /// True while a list or detail is being loaded.
  bool get isLoading => _loading;

  /// True while a write (create, advance, close) is in flight.
  bool get isBusy => _busy;

  /// Last failure, or `null`. Cleared by the next operation or [clearError].
  PqrsFailure? get error => _error;

  /// True once a load finished without error and there is nothing to show.
  bool get isEmpty =>
      _loaded && !_loading && _error == null && _requests.isEmpty;

  /// "Datos guardados, sin conexión" while the last read used the local copy;
  /// `null` otherwise (or when the repository has no local copy).
  String? get notice {
    final Object source = _repository;
    return source is PqrsNoticeSource ? source.notice : null;
  }

  /// Role of the session, or `null` without one.
  PqrsActor? get role => _session?.role;

  /// uid of the session, or `null` without one.
  String? get uid => _session?.uid;

  /// Current time of the injected clock; the views use it to decide whether
  /// the confirmation deadline has expired.
  DateTime get now => _clock();

  /// True when [request] is resolved and its confirmation deadline has
  /// expired. The device clock only decides visibility; Firestore decides.
  bool isOverdue(PqrsRequest request) =>
      request.canBeClosedByOwnerTimeout(_clock());

  /// Request created by the last successful [createRequest].
  PqrsRequest? get lastCreated => _lastCreated;

  void clearError() {
    _error = null;
    _notify();
  }

  /// Repeats the last failed operation (same trace id, so it is idempotent).
  Future<bool> retry() async {
    final action = _retryAction;
    if (action == null) return false;
    return action();
  }

  // ----------------------------------------------------------------- reads

  /// All loaded requests, in the order the repository returned them.
  List<PqrsRequest> get all => List.unmodifiable(_requests);

  List<PqrsRequest> byMotel(String motelId) =>
      _requests.where((request) => request.motelId == motelId).toList();

  List<PqrsRequest> byClient(String clientId) =>
      _requests.where((request) => request.clientId == clientId).toList();

  /// Returns the request or `null` when it is not loaded.
  PqrsRequest? findById(String requestId) {
    for (final request in _requests) {
      if (request.id == requestId) return request;
    }
    return null;
  }

  PqrsRequest byId(String requestId) {
    final request = findById(requestId);
    if (request == null) throw StateError(_notFoundMessage);
    return request;
  }

  /// Ids of the motels that have at least one loaded request.
  Set<String> get motelIdsWithRequests => {
    for (final request in _requests) request.motelId,
  };

  /// Synchronization state of a request (synced when unknown).
  PqrsSyncState syncOf(String requestId) =>
      _sync[requestId] ?? PqrsSyncState.synced;

  // ---------------------------------------------------------------- loading

  /// Loads the requests that belong to the session role.
  Future<bool> loadRequests() async {
    _retryAction = loadRequests;
    final session = _session;
    if (session == null) {
      _fail(
        const PqrsFailure(PqrsFailureKind.permission, _loginRequiredMessage),
      );
      return false;
    }
    _loading = true;
    _error = null;
    _notify();
    try {
      final records = switch (session.role) {
        PqrsActor.client => await _repository.listByClient(session.uid),
        PqrsActor.owner => await _repository.listByOwner(session.uid),
        PqrsActor.systemAdmin => await _repository.listAll(),
      };
      _requests
        ..clear()
        ..addAll(records.map((record) => record.request));
      _sync
        ..clear()
        ..addEntries(records.map((r) => MapEntry(r.request.id, r.sync)));
      _loaded = true;
      _loading = false;
      _retryAction = null;
      _notify();
      return true;
    } on Object catch (error) {
      _loading = false;
      _fail(_toFailure(error));
      return false;
    }
  }

  /// Reloads one request with its full trace.
  Future<bool> loadDetail(String requestId) async {
    _retryAction = () => loadDetail(requestId);
    _loading = true;
    _error = null;
    _notify();
    try {
      final record = await _repository.getDetail(requestId);
      _loading = false;
      if (record == null) {
        _fail(const PqrsFailure(PqrsFailureKind.notFound, _notFoundMessage));
        return false;
      }
      _store(record);
      _retryAction = null;
      _notify();
      return true;
    } on Object catch (error) {
      _loading = false;
      _fail(_toFailure(error));
      return false;
    }
  }

  /// Photos of a request, requested only when the detail needs them.
  ///
  /// They are optional content: a failure (for example without connection)
  /// leaves the placeholders and does not raise the error state of the screen.
  Future<List<PqrsAttachment>> loadPhotos(String requestId) async {
    try {
      return await _repository.getPhotos(requestId);
    } on Object catch (error) {
      debugPrint('PQRS: photos ${error.runtimeType}');
      return const [];
    }
  }

  // --------------------------------------------------------------- creation

  /// Registers a new request opened by the session client.
  Future<bool> createRequest({
    required String motelId,
    required String motelName,
    required String ownerId,
    required PqrsType? type,
    required String subject,
    required String description,
    List<PqrsAttachment> attachments = const [],
  }) async {
    PqrsNewRequest? built;
    PqrsNewRequest plan() {
      final existing = built;
      if (existing != null) return existing;
      final session = _requireSession();
      if (session.role != PqrsActor.client) throw _noPermission();
      if (motelId.trim().isEmpty) {
        throw const PqrsFailure(
          PqrsFailureKind.validation,
          PqrsValidator.motelRequiredMessage,
        );
      }
      if (type == null) {
        throw const PqrsFailure(
          PqrsFailureKind.validation,
          PqrsValidator.typeRequiredMessage,
        );
      }
      _validate(PqrsValidator.subject(subject));
      _validate(PqrsValidator.description(description));
      _validate(PqrsValidator.photoCount(attachments.length, max: _maxPhotos));
      return built = PqrsNewRequest(
        id: _nextId('pqrs'),
        motelId: motelId,
        motelName: motelName,
        clientId: session.uid,
        clientName: session.name,
        ownerId: ownerId,
        type: type,
        subject: subject.trim(),
        description: description.trim(),
        createdAt: _clock(),
        photos: List.unmodifiable(attachments),
      );
    }

    Future<bool> run() => _write(() async {
      final record = await _repository.create(plan());
      _store(record);
      _lastCreated = record.request;
    }, run);
    return run();
  }

  // --------------------------------------------------------------- advances

  /// Appends a comment with optional photos.
  ///
  /// Client: never changes the status, except on a resolved request, which it
  /// reopens (in progress, resolvedAt removed). Owner: the first answer moves
  /// pending to in progress; it cannot comment on a resolved request.
  Future<bool> addUpdate({
    required String requestId,
    required String message,
    List<PqrsAttachment> attachments = const [],
  }) => _advance(() {
    final session = _requireSession();
    final request = _requireOpen(requestId);
    _validate(PqrsValidator.message(message));
    _validate(PqrsValidator.photoCount(attachments.length, max: _maxPhotos));

    PqrsStatus? change;
    var reopen = false;
    switch (session.role) {
      case PqrsActor.client:
        _requireOwnRequest(session, request);
        if (request.status == PqrsStatus.resolved) {
          change = PqrsStatus.inProgress;
          reopen = true;
        }
      case PqrsActor.owner:
        if (request.status == PqrsStatus.resolved) {
          throw const PqrsFailure(
            PqrsFailureKind.validation,
            'La solicitud ya espera la confirmación del cliente',
          );
        }
        if (request.status == PqrsStatus.pending) {
          change = PqrsStatus.inProgress;
        }
      case PqrsActor.systemAdmin:
        throw _noPermission();
    }
    return PqrsTraceAppend(
      requestId: requestId,
      entry: _entry(session, message.trim(), attachments, change),
      clearResolvedAt: reopen,
    );
  });

  /// The owner proposes a solution and waits for the client to confirm it.
  Future<bool> markResolved({
    required String requestId,
    required String message,
    List<PqrsAttachment> attachments = const [],
  }) => _advance(() {
    final session = _requireOwner();
    final request = _requireOpen(requestId);
    if (request.status == PqrsStatus.resolved) {
      throw const PqrsFailure(
        PqrsFailureKind.validation,
        'La solicitud ya está marcada como solucionada',
      );
    }
    _validate(PqrsValidator.message(message));
    _validate(PqrsValidator.photoCount(attachments.length, max: _maxPhotos));
    final entry = _entry(
      session,
      message.trim(),
      attachments,
      PqrsStatus.resolved,
    );
    return PqrsTraceAppend(
      requestId: requestId,
      entry: entry,
      resolvedAt: entry.createdAt,
    );
  });

  /// The owner rejects a pending or in progress request, stating the reason.
  Future<bool> reject({required String requestId, required String message}) =>
      _advance(() {
        final session = _requireOwner();
        final request = _requireOpen(requestId);
        if (request.status == PqrsStatus.resolved) {
          throw const PqrsFailure(
            PqrsFailureKind.validation,
            'Una solicitud solucionada no se puede rechazar',
          );
        }
        _validate(PqrsValidator.rejectReason(message));
        return PqrsTraceAppend(
          requestId: requestId,
          entry: _entry(session, message.trim(), const [], PqrsStatus.rejected),
        );
      });

  /// The client confirms the solution and closes the request.
  Future<bool> closeByClient({
    required String requestId,
    String message = '',
  }) => _advance(() {
    final session = _requireSession();
    if (session.role != PqrsActor.client) throw _noPermission();
    final request = _requireOpen(requestId);
    _requireOwnRequest(session, request);
    if (!request.canBeClosedByClient) {
      throw const PqrsFailure(
        PqrsFailureKind.validation,
        'Solo se puede cerrar una solicitud solucionada',
      );
    }
    final text = message.trim();
    if (text.isNotEmpty) _validate(PqrsValidator.message(text));
    return PqrsTraceAppend(
      requestId: requestId,
      entry: _entry(
        session,
        text.isEmpty ? pqrsClientClosureMessage : text,
        const [],
        PqrsStatus.closed,
      ),
      closedBy: PqrsClosedBy.client,
    );
  });

  /// The owner closes a resolved request once the client let the
  /// confirmation deadline (7 days from resolvedAt) pass.
  ///
  /// The device clock only simulates the check; Firestore uses server time.
  Future<bool> closeByTimeout({required String requestId}) => _advance(() {
    final session = _requireOwner();
    final request = _requireOpen(requestId);
    if (!request.canBeClosedByOwnerTimeout(_clock())) {
      throw const PqrsFailure(
        PqrsFailureKind.validation,
        'Aún no vence el plazo de confirmación del cliente',
      );
    }
    return PqrsTraceAppend(
      requestId: requestId,
      entry: _entry(
        session,
        pqrsTimeoutClosureMessage,
        const [],
        PqrsStatus.closed,
      ),
      closedBy: PqrsClosedBy.ownerTimeout,
    );
  });

  // ------------------------------------------------------ pending actions

  /// Retries sending pending or failed local actions, then reloads.
  Future<bool> retryPending({String? requestId}) => _write(() async {
    await _repository.retryPending(requestId: requestId);
    if (requestId != null) {
      final record = await _repository.getDetail(requestId);
      if (record != null) _store(record);
    }
  }, () => retryPending(requestId: requestId));

  /// Drops the pending or failed local action and restores the synced copy.
  Future<bool> discardPending(String requestId) => _write(() async {
    await _repository.discardPending(requestId);
    final record = await _repository.getDetail(requestId);
    if (record != null) {
      _store(record);
    } else {
      // A discarded creation leaves nothing to show.
      _requests.removeWhere((request) => request.id == requestId);
      _sync.remove(requestId);
    }
  }, () => discardPending(requestId));

  // ---------------------------------------------------------------- helpers

  /// Plans (validating) and sends ONE atomic [PqrsTraceAppend]. The plan is
  /// built once so a retry reuses the same trace id.
  Future<bool> _advance(PqrsTraceAppend Function() plan) {
    PqrsTraceAppend? built;
    Future<bool> run() => _write(() async {
      final action = built ??= plan();
      _store(await _repository.appendTrace(action));
    }, run);
    return run();
  }

  /// Runs [body] with busy/error handling; [retry] is stored for [retry].
  Future<bool> _write(
    Future<void> Function() body,
    Future<bool> Function() retry,
  ) async {
    _retryAction = retry;
    _busy = true;
    _error = null;
    _notify();
    try {
      await body();
      _busy = false;
      _retryAction = null;
      _notify();
      return true;
    } on Object catch (error) {
      _busy = false;
      _fail(_toFailure(error));
      return false;
    }
  }

  void _store(PqrsRecord record) {
    final index = _requests.indexWhere((r) => r.id == record.request.id);
    if (index < 0) {
      _requests.insert(0, record.request);
    } else {
      _requests[index] = record.request;
    }
    _sync[record.request.id] = record.sync;
  }

  PqrsTraceEntry _entry(
    PqrsSession session,
    String message,
    List<PqrsAttachment> attachments,
    PqrsStatus? change,
  ) => PqrsTraceEntry(
    id: _nextId('trace'),
    author: session.role,
    authorId: session.uid,
    authorName: session.name,
    message: message,
    createdAt: _clock(),
    attachments: List.unmodifiable(attachments),
    statusChange: change,
  );

  PqrsSession _requireSession() {
    final session = _session;
    if (session == null) {
      throw const PqrsFailure(
        PqrsFailureKind.permission,
        _loginRequiredMessage,
      );
    }
    return session;
  }

  PqrsSession _requireOwner() {
    final session = _requireSession();
    if (session.role != PqrsActor.owner) throw _noPermission();
    return session;
  }

  void _requireOwnRequest(PqrsSession session, PqrsRequest request) {
    if (request.clientId != session.uid) throw _noPermission();
  }

  PqrsRequest _requireOpen(String requestId) {
    final request = findById(requestId);
    if (request == null) {
      throw const PqrsFailure(PqrsFailureKind.notFound, _notFoundMessage);
    }
    if (request.status.isFinal) {
      throw const PqrsFailure(PqrsFailureKind.validation, _finalMessage);
    }
    return request;
  }

  PqrsFailure _noPermission() =>
      const PqrsFailure(PqrsFailureKind.permission, _noPermissionMessage);

  void _validate(String? message) {
    if (message != null) {
      throw PqrsFailure(PqrsFailureKind.validation, message);
    }
  }

  PqrsFailure _toFailure(Object error) {
    if (error is PqrsFailure) return error;
    // Only the type is logged: the error may carry user data.
    debugPrint('PQRS: unexpected ${error.runtimeType}');
    return const PqrsFailure(PqrsFailureKind.unknown, _unknownMessage);
  }

  void _fail(PqrsFailure failure) {
    _error = failure;
    _notify();
  }

  String _nextId(String prefix) =>
      '$prefix-${_clock().microsecondsSinceEpoch}-${_sequence++}';

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
