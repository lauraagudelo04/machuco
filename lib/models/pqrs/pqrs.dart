import 'dart:typed_data';

/// Kind of PQRS request submitted by a client.
enum PqrsType { peticion, queja, reclamo, sugerencia }

/// Lifecycle of a PQRS request.
///
/// The owner attends and proposes a solution ([resolved]); only the client who
/// created the request may confirm it and move it to [closed]. The owner may
/// also close it once the confirmation deadline expires.
enum PqrsStatus { pending, inProgress, resolved, closed, rejected }

extension PqrsStatusRules on PqrsStatus {
  /// A closed or rejected request is final: it accepts no further updates.
  bool get isFinal => this == PqrsStatus.closed || this == PqrsStatus.rejected;
}

/// Who closed a request that reached [PqrsStatus.closed].
///
/// [key] is the value stored in Firestore (`closedBy`).
enum PqrsClosedBy {
  /// The client confirmed the proposed solution.
  client('client'),

  /// The owner closed it after the confirmation deadline expired.
  ownerTimeout('owner_timeout');

  const PqrsClosedBy(this.key);

  final String key;

  /// Parses a stored key; returns `null` when absent or unknown.
  static PqrsClosedBy? fromKey(String? key) {
    for (final value in values) {
      if (value.key == key) return value;
    }
    return null;
  }
}

/// Time the client has to confirm a solution before the owner may close the
/// request. It must match `duration.value(7, 'd')` in `firestore.rules`.
const pqrsConfirmationDeadline = Duration(days: 7);

/// Who produced a trace entry.
enum PqrsActor { client, owner, systemAdmin }

/// A photo attached to a trace entry.
///
/// [bytes] and [mimeType] carry the real compressed image. Photos listed
/// without their bytes still show a placeholder; [seed] only varies it.
class PqrsAttachment {
  const PqrsAttachment({
    required this.id,
    required this.label,
    required this.author,
    required this.capturedAt,
    required this.seed,
    this.bytes,
    this.mimeType,
  });

  final String id;
  final String label;
  final PqrsActor author;
  final DateTime capturedAt;
  final int seed;

  /// Compressed image bytes. `null` while the photo has not been downloaded.
  final Uint8List? bytes;

  /// MIME type of [bytes] (for example `image/jpeg`).
  final String? mimeType;

  /// True when the attachment carries a real image that can be stored.
  bool get hasImage => bytes != null && mimeType != null;
}

/// One traceability step: a comment, optional photos and an optional status
/// change, always attributed to the actor that produced it.
class PqrsTraceEntry {
  const PqrsTraceEntry({
    required this.id,
    required this.author,
    required this.authorId,
    required this.message,
    required this.createdAt,
    this.authorName = '',
    this.attachments = const [],
    this.statusChange,
  });

  final String id;
  final PqrsActor author;

  /// Denormalized display name of the author; empty when unknown.
  final String authorName;

  /// uid of the author (the client id or the owner id).
  final String authorId;
  final String message;
  final DateTime createdAt;
  final List<PqrsAttachment> attachments;
  final PqrsStatus? statusChange;
}

/// A PQRS request, together with its full traceability.
class PqrsRequest {
  const PqrsRequest({
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
    this.status = PqrsStatus.pending,
    this.resolvedAt,
    this.closedBy,
    this.trace = const [],
    this.attachments = const [],
  });

  final String id;
  final String motelId;

  /// Motel name denormalized when the request is filed, so lists render
  /// without reading the motel again. Not updated if the motel is renamed.
  final String motelName;
  final String clientId;
  final String clientName;

  /// uid of the owner of the motel.
  final String ownerId;
  final PqrsType type;
  final String subject;
  final String description;
  final DateTime createdAt;
  final PqrsStatus status;

  /// Moment the request became [PqrsStatus.resolved]; null when it never was
  /// or when it was reopened. Base of the confirmation deadline.
  final DateTime? resolvedAt;

  /// Who closed the request. Closed requests without it count as
  /// [PqrsClosedBy.client].
  final PqrsClosedBy? closedBy;

  /// Trace entries in chronological order.
  final List<PqrsTraceEntry> trace;

  /// Photos attached when the client opened the request.
  final List<PqrsAttachment> attachments;

  /// Returns a copy. Pass [clearResolvedAt] to remove [resolvedAt] (the
  /// request went back to in progress).
  PqrsRequest copyWith({
    PqrsStatus? status,
    List<PqrsTraceEntry>? trace,
    DateTime? resolvedAt,
    bool clearResolvedAt = false,
    PqrsClosedBy? closedBy,
  }) {
    return PqrsRequest(
      id: id,
      motelId: motelId,
      motelName: motelName,
      clientId: clientId,
      clientName: clientName,
      ownerId: ownerId,
      type: type,
      subject: subject,
      description: description,
      createdAt: createdAt,
      status: status ?? this.status,
      resolvedAt: clearResolvedAt ? null : (resolvedAt ?? this.resolvedAt),
      closedBy: closedBy ?? this.closedBy,
      trace: trace ?? this.trace,
      attachments: attachments,
    );
  }

  /// Every photo of the request: the opening ones plus those in the trace.
  List<PqrsAttachment> get allAttachments => [
    ...attachments,
    for (final entry in trace) ...entry.attachments,
  ];

  /// Time between creation and the first owner answer, when it exists.
  Duration? get firstResponseTime {
    for (final entry in trace) {
      if (entry.author == PqrsActor.owner) {
        return entry.createdAt.difference(createdAt);
      }
    }
    return null;
  }

  /// True while the client is allowed to confirm the proposed solution.
  bool get canBeClosedByClient => status == PqrsStatus.resolved;

  /// Date after which the owner may close the request for lack of answer, or
  /// null when the request is not resolved.
  DateTime? get confirmationDeadline {
    final at = resolvedAt;
    if (status != PqrsStatus.resolved || at == null) return null;
    return at.add(pqrsConfirmationDeadline);
  }

  /// True when the request is resolved and [now] is past the deadline. The
  /// device clock only decides visibility; Firestore rules use server time.
  bool canBeClosedByOwnerTimeout(DateTime now) {
    final deadline = confirmationDeadline;
    return deadline != null && now.isAfter(deadline);
  }
}

/// Aggregated PQRS indicators used by the owner and system administrator
/// statistics panels.
class PqrsStats {
  const PqrsStats._({
    required this.total,
    required this.countsByStatus,
    required this.closedByTimeoutCount,
    required this.averageFirstResponse,
  });

  factory PqrsStats.from(List<PqrsRequest> requests) {
    final counts = <PqrsStatus, int>{
      for (final status in PqrsStatus.values) status: 0,
    };
    var timeouts = 0;
    var responseTotal = Duration.zero;
    var responseCount = 0;

    for (final request in requests) {
      counts[request.status] = (counts[request.status] ?? 0) + 1;
      if (request.status == PqrsStatus.closed &&
          request.closedBy == PqrsClosedBy.ownerTimeout) {
        timeouts++;
      }
      final response = request.firstResponseTime;
      if (response != null) {
        responseTotal += response;
        responseCount++;
      }
    }

    return PqrsStats._(
      total: requests.length,
      countsByStatus: Map.unmodifiable(counts),
      closedByTimeoutCount: timeouts,
      averageFirstResponse: responseCount == 0
          ? null
          : Duration(
              microseconds: responseTotal.inMicroseconds ~/ responseCount,
            ),
    );
  }

  final int total;

  /// Amount of requests per status, unmodifiable.
  final Map<PqrsStatus, int> countsByStatus;

  /// Closed requests whose closedBy is [PqrsClosedBy.ownerTimeout].
  final int closedByTimeoutCount;

  /// Average time the owner takes to answer for the first time, or `null` when
  /// no request has been answered yet.
  final Duration? averageFirstResponse;

  int countOf(PqrsStatus status) => countsByStatus[status] ?? 0;

  /// Share of requests that left the pending queue.
  double get attentionRate => _rate(total - countOf(PqrsStatus.pending), total);

  /// (resolved + closed) / total.
  double get solutionRate =>
      _rate(countOf(PqrsStatus.resolved) + countOf(PqrsStatus.closed), total);

  /// Closed by the client (or without closedBy) / (resolved + closed).
  /// Timeout closures stay in the denominator only.
  double get closureRate => _rate(
    countOf(PqrsStatus.closed) - closedByTimeoutCount,
    countOf(PqrsStatus.resolved) + countOf(PqrsStatus.closed),
  );

  double _rate(int amount, int denominator) =>
      denominator == 0 ? 0 : amount / denominator;
}
