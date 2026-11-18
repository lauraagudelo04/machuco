import 'package:machuco/database/model/pqrs/pqrs_cache_entry.dart';
import 'package:machuco/database/model/pqrs/pqrs_firestore_document.dart';
import 'package:machuco/models/pqrs/pqrs.dart';

/// Converts between the domain model and the local cache rows. Dates are epoch
/// milliseconds. Readers throw [FormatException] on a row that cannot be read.
abstract final class PqrsCacheMapper {
  static PqrsCacheEntry toEntry(PqrsRequest request) => PqrsCacheEntry(
    id: request.id,
    clientId: request.clientId,
    ownerId: request.ownerId,
    motelId: request.motelId,
    motelName: request.motelName,
    clientName: request.clientName,
    type: request.type.name,
    subject: request.subject,
    description: request.description,
    status: PqrsFirestoreDocument.statusToKey(request.status),
    resolvedAt: request.resolvedAt?.millisecondsSinceEpoch,
    closedBy: request.closedBy?.key,
    photoCount: request.attachments.length,
    createdAt: request.createdAt.millisecondsSinceEpoch,
    // The domain model does not carry updatedAt; the cache only sorts by
    // createdAt.
    updatedAt: request.createdAt.millisecondsSinceEpoch,
  );

  static PqrsTraceCacheEntry toTraceEntry(
    String pqrsId,
    PqrsTraceEntry trace,
  ) => PqrsTraceCacheEntry(
    id: trace.id,
    pqrsId: pqrsId,
    authorId: trace.authorId,
    authorRole: PqrsFirestoreDocument.actorToKey(trace.author),
    authorName: trace.authorName.isEmpty ? null : trace.authorName,
    message: trace.message,
    statusChange: trace.statusChange == null
        ? null
        : PqrsFirestoreDocument.statusToKey(trace.statusChange!),
    photoCount: trace.attachments.length,
    createdAt: trace.createdAt.millisecondsSinceEpoch,
  );

  static PqrsRequest toRequest(
    PqrsCacheEntry entry, {
    List<PqrsTraceCacheEntry> traces = const [],
  }) {
    final resolvedAt = entry.resolvedAt;
    return PqrsRequest(
      id: entry.id,
      motelId: entry.motelId,
      motelName: entry.motelName,
      clientId: entry.clientId,
      clientName: entry.clientName,
      ownerId: entry.ownerId,
      type: _type(entry.type),
      subject: entry.subject,
      description: entry.description,
      createdAt: DateTime.fromMillisecondsSinceEpoch(entry.createdAt),
      status: PqrsFirestoreDocument.statusFromKey(entry.status),
      resolvedAt: resolvedAt == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(resolvedAt),
      closedBy: PqrsClosedBy.fromKey(entry.closedBy),
      trace: List.unmodifiable(traces.map(_toTrace)),
    );
  }

  static PqrsTraceEntry _toTrace(PqrsTraceCacheEntry entry) {
    final change = entry.statusChange;
    return PqrsTraceEntry(
      id: entry.id,
      author: PqrsFirestoreDocument.actorFromKey(entry.authorRole),
      authorId: entry.authorId,
      authorName: entry.authorName ?? '',
      message: entry.message,
      createdAt: DateTime.fromMillisecondsSinceEpoch(entry.createdAt),
      statusChange: change == null
          ? null
          : PqrsFirestoreDocument.statusFromKey(change),
    );
  }

  static PqrsType _type(String key) {
    for (final type in PqrsType.values) {
      if (type.name == key) return type;
    }
    throw FormatException('Tipo PQRS desconocido: $key');
  }
}
