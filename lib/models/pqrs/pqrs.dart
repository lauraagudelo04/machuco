/// Kind of PQRS request submitted by a client.
enum PqrsType { peticion, queja, reclamo, sugerencia }

/// Lifecycle of a PQRS request.
///
/// The owner attends and proposes a solution ([resolved]); only the client who
/// created the request may confirm it and move it to [closed].
enum PqrsStatus { pending, inProgress, resolved, closed, rejected }

extension PqrsStatusRules on PqrsStatus {
  /// A closed or rejected request is final: it accepts no further updates.
  bool get isFinal => this == PqrsStatus.closed || this == PqrsStatus.rejected;
}

/// Who produced a trace entry.
enum PqrsActor { client, owner, systemAdmin }

/// A photo attached to a trace entry.
///
/// There is no image picker in the project yet, so an attachment is simulated:
/// [seed] drives a deterministic placeholder rendered by the view layer.
class PqrsAttachment {
  const PqrsAttachment({
    required this.id,
    required this.label,
    required this.author,
    required this.capturedAt,
    required this.seed,
  });

  /// Builds a simulated attachment with a deterministic placeholder.
  factory PqrsAttachment.simulated({
    required PqrsActor author,
    required String label,
    DateTime? capturedAt,
    int? seed,
  }) {
    final now = capturedAt ?? DateTime.now();
    return PqrsAttachment(
      id: 'att-${now.microsecondsSinceEpoch}-${label.hashCode}',
      label: label,
      author: author,
      capturedAt: now,
      seed: seed ?? label.hashCode.abs(),
    );
  }

  final String id;
  final String label;
  final PqrsActor author;
  final DateTime capturedAt;
  final int seed;
}

/// One traceability step: a comment, optional photos and an optional status
/// change, always attributed to the actor that produced it.
class PqrsTraceEntry {
  const PqrsTraceEntry({
    required this.id,
    required this.author,
    required this.message,
    required this.createdAt,
    this.attachments = const [],
    this.statusChange,
  });

  final String id;
  final PqrsActor author;
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
    required this.type,
    required this.subject,
    required this.description,
    required this.createdAt,
    this.status = PqrsStatus.pending,
    this.trace = const [],
    this.attachments = const [],
  });

  final String id;
  final String motelId;
  final String motelName;
  final String clientId;
  final String clientName;
  final PqrsType type;
  final String subject;
  final String description;
  final DateTime createdAt;
  final PqrsStatus status;

  /// Trace entries in chronological order.
  final List<PqrsTraceEntry> trace;

  /// Photos attached when the client opened the request.
  final List<PqrsAttachment> attachments;

  PqrsRequest copyWith({PqrsStatus? status, List<PqrsTraceEntry>? trace}) {
    return PqrsRequest(
      id: id,
      motelId: motelId,
      motelName: motelName,
      clientId: clientId,
      clientName: clientName,
      type: type,
      subject: subject,
      description: description,
      createdAt: createdAt,
      status: status ?? this.status,
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
}

/// Aggregated PQRS indicators used by the owner and system administrator
/// statistics panels.
class PqrsStats {
  const PqrsStats._({
    required this.total,
    required this.countsByStatus,
    required this.averageFirstResponse,
  });

  factory PqrsStats.from(List<PqrsRequest> requests) {
    final counts = <PqrsStatus, int>{
      for (final status in PqrsStatus.values) status: 0,
    };
    var responseTotal = Duration.zero;
    var responseCount = 0;

    for (final request in requests) {
      counts[request.status] = counts[request.status]! + 1;
      final response = request.firstResponseTime;
      if (response != null) {
        responseTotal += response;
        responseCount++;
      }
    }

    return PqrsStats._(
      total: requests.length,
      countsByStatus: Map.unmodifiable(counts),
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

  /// Average time the owner takes to answer for the first time, or `null` when
  /// no request has been answered yet.
  final Duration? averageFirstResponse;

  int countOf(PqrsStatus status) => countsByStatus[status] ?? 0;

  /// Share of requests that left the pending queue.
  double get attentionRate => _rate(total - countOf(PqrsStatus.pending));

  /// Share of requests with a solution proposed or already confirmed.
  double get resolutionRate =>
      _rate(countOf(PqrsStatus.resolved) + countOf(PqrsStatus.closed));

  /// Share of requests the client confirmed as solved.
  double get closureRate => _rate(countOf(PqrsStatus.closed));

  double _rate(int amount) => total == 0 ? 0 : amount / total;
}
