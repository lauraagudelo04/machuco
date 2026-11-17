import 'package:floor/floor.dart';

/// Local copy of the last read of `pqrs/{id}` (Firestore). Dates are epoch
/// milliseconds. It is only a cache: Firestore stays the source of truth.
@Entity(
  tableName: 'pqrs_cache',
  indices: [
    Index(value: ['clientId']),
    Index(value: ['ownerId']),
  ],
)
class PqrsCacheEntry {
  const PqrsCacheEntry({
    required this.id,
    required this.clientId,
    required this.ownerId,
    required this.motelId,
    required this.motelName,
    required this.clientName,
    required this.type,
    required this.subject,
    required this.description,
    required this.status,
    required this.photoCount,
    required this.createdAt,
    required this.updatedAt,
    this.resolvedAt,
    this.closedBy,
  });

  @PrimaryKey()
  final String id;
  final String clientId;
  final String ownerId;
  final String motelId;
  final String motelName;
  final String clientName;

  /// Stable type code (`peticion`, `queja`, `reclamo`, `sugerencia`).
  final String type;
  final String subject;
  final String description;
  final String status;

  /// Epoch milliseconds; null while the request is not resolved.
  final int? resolvedAt;

  /// `client` or `owner_timeout`; null when it was not closed.
  final String? closedBy;
  final int photoCount;
  final int createdAt;
  final int updatedAt;
}

/// Local copy of `pqrs/{id}/traces/{traceId}`.
@Entity(
  tableName: 'pqrs_trace_cache',
  indices: [
    Index(value: ['pqrsId']),
  ],
)
class PqrsTraceCacheEntry {
  const PqrsTraceCacheEntry({
    required this.id,
    required this.pqrsId,
    required this.authorId,
    required this.authorRole,
    required this.message,
    required this.photoCount,
    required this.createdAt,
    this.authorName,
    this.statusChange,
  });

  @PrimaryKey()
  final String id;
  final String pqrsId;
  final String authorId;
  final String authorRole;
  final String? authorName;
  final String message;

  /// New status stored by this trace, or null when it is only a comment.
  final String? statusChange;
  final int photoCount;
  final int createdAt;
}
