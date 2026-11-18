import 'dart:convert';

import 'package:machuco/database/model/pqrs/pqrs_firestore_document.dart';
import 'package:machuco/database/model/pqrs/pqrs_outbox_entry.dart';
import 'package:machuco/database/repository/pqrs/pqrs_repository.dart';
import 'package:machuco/models/pqrs/pqrs.dart';

/// Converts the actions of the repository contract to and from outbox rows.
///
/// The outbox row id is the trace id generated on the client, and the photo
/// ids are `<traceId>_1` to `_10`, so sending the same row twice writes the same
/// documents. The JSON never carries photos (they have their own rows). Readers
/// throw [FormatException] when a row cannot be understood.
abstract final class PqrsOutboxCodec {
  /// Row of a new request. Its id is the id of the opening trace entry.
  static (PqrsOutboxEntry, List<PqrsOutboxPhotoEntry>) encodeCreate(
    PqrsNewRequest request, {
    required int createdAt,
  }) {
    final id = pqrsOpeningTraceId(request.id);
    final entry = PqrsOutboxEntry(
      id: id,
      pqrsId: request.id,
      action: PqrsOutboxAction.create,
      payload: jsonEncode({
        'motelId': request.motelId,
        'motelName': request.motelName,
        'clientId': request.clientId,
        'clientName': request.clientName,
        'ownerId': request.ownerId,
        'type': request.type.name,
        'subject': request.subject,
        'description': request.description,
        'createdAt': request.createdAt.millisecondsSinceEpoch,
      }),
      syncStatus: PqrsOutboxStatus.pendingSync,
      createdAt: createdAt,
    );
    return (entry, _photoRows(id, request.photos));
  }

  /// Row of a trace entry with its optional status change.
  static (PqrsOutboxEntry, List<PqrsOutboxPhotoEntry>) encodeAppend(
    PqrsTraceAppend action, {
    required int createdAt,
  }) {
    final trace = action.entry;
    final entry = PqrsOutboxEntry(
      id: trace.id,
      pqrsId: action.requestId,
      action: _actionOf(trace.statusChange),
      payload: jsonEncode({
        'authorId': trace.authorId,
        'authorRole': PqrsFirestoreDocument.actorToKey(trace.author),
        'authorName': trace.authorName,
        'message': trace.message,
        'createdAt': trace.createdAt.millisecondsSinceEpoch,
        'statusChange': trace.statusChange == null
            ? null
            : PqrsFirestoreDocument.statusToKey(trace.statusChange!),
        'resolvedAt': action.resolvedAt?.millisecondsSinceEpoch,
        'clearResolvedAt': action.clearResolvedAt,
        'closedBy': action.closedBy?.key,
      }),
      syncStatus: PqrsOutboxStatus.pendingSync,
      createdAt: createdAt,
    );
    return (entry, _photoRows(trace.id, trace.attachments));
  }

  static String _actionOf(PqrsStatus? change) => switch (change) {
    null => PqrsOutboxAction.comment,
    PqrsStatus.resolved => PqrsOutboxAction.resolve,
    PqrsStatus.rejected => PqrsOutboxAction.reject,
    PqrsStatus.closed => PqrsOutboxAction.close,
    PqrsStatus.pending || PqrsStatus.inProgress => PqrsOutboxAction.advance,
  };

  static List<PqrsOutboxPhotoEntry> _photoRows(
    String outboxId,
    List<PqrsAttachment> attachments,
  ) {
    final photos = PqrsFirestoreDocument.storablePhotos(attachments);
    return [
      for (var index = 0; index < photos.length; index++)
        PqrsOutboxPhotoEntry(
          id: pqrsPhotoId(outboxId, index + 1),
          outboxId: outboxId,
          mimeType: photos[index].mimeType!,
          bytes: photos[index].bytes!,
        ),
    ];
  }

  // ---------------------------------------------------------------- readers

  static bool isCreate(PqrsOutboxEntry entry) =>
      entry.action == PqrsOutboxAction.create;

  /// uid of whoever wrote the action (the client for a new request).
  static String authorIdOf(PqrsOutboxEntry entry) {
    final json = _json(entry);
    return _string(json, isCreate(entry) ? 'clientId' : 'authorId');
  }

  static PqrsNewRequest decodeCreate(
    PqrsOutboxEntry entry,
    List<PqrsOutboxPhotoEntry> photos,
  ) {
    final json = _json(entry);
    final createdAt = _date(json, 'createdAt');
    return PqrsNewRequest(
      id: entry.pqrsId,
      motelId: _string(json, 'motelId'),
      motelName: _string(json, 'motelName'),
      clientId: _string(json, 'clientId'),
      clientName: _string(json, 'clientName'),
      ownerId: _string(json, 'ownerId'),
      type: _type(json['type']),
      subject: _string(json, 'subject'),
      description: _string(json, 'description'),
      createdAt: createdAt,
      photos: _attachments(photos, PqrsActor.client, createdAt),
    );
  }

  static PqrsTraceAppend decodeAppend(
    PqrsOutboxEntry entry,
    List<PqrsOutboxPhotoEntry> photos,
  ) {
    final json = _json(entry);
    final createdAt = _date(json, 'createdAt');
    final author = PqrsFirestoreDocument.actorFromKey(json['authorRole']);
    final change = json['statusChange'];
    final resolvedAt = json['resolvedAt'];
    return PqrsTraceAppend(
      requestId: entry.pqrsId,
      entry: PqrsTraceEntry(
        id: entry.id,
        author: author,
        authorId: _string(json, 'authorId'),
        authorName: json['authorName'] as String? ?? '',
        message: _string(json, 'message'),
        createdAt: createdAt,
        attachments: _attachments(photos, author, createdAt),
        statusChange: change == null
            ? null
            : PqrsFirestoreDocument.statusFromKey(change),
      ),
      resolvedAt: resolvedAt is int
          ? DateTime.fromMillisecondsSinceEpoch(resolvedAt)
          : null,
      clearResolvedAt: json['clearResolvedAt'] == true,
      closedBy: PqrsClosedBy.fromKey(json['closedBy'] as String?),
    );
  }

  /// Request as it would look right after the action was accepted.
  static PqrsRequest requestOfCreate(PqrsOutboxEntry entry) {
    final request = decodeCreate(entry, const []);
    return PqrsRequest(
      id: request.id,
      motelId: request.motelId,
      motelName: request.motelName,
      clientId: request.clientId,
      clientName: request.clientName,
      ownerId: request.ownerId,
      type: request.type,
      subject: request.subject,
      description: request.description,
      createdAt: request.createdAt,
    );
  }

  static List<PqrsAttachment> _attachments(
    List<PqrsOutboxPhotoEntry> rows,
    PqrsActor author,
    DateTime capturedAt,
  ) => [
    for (var index = 0; index < rows.length; index++)
      PqrsAttachment(
        id: rows[index].id,
        label: 'Foto ${index + 1}',
        author: author,
        capturedAt: capturedAt,
        seed: 0,
        bytes: rows[index].bytes,
        mimeType: rows[index].mimeType,
      ),
  ];

  static Map<String, dynamic> _json(PqrsOutboxEntry entry) {
    final decoded = jsonDecode(entry.payload);
    if (decoded is Map<String, dynamic>) return decoded;
    throw const FormatException('Acción guardada inválida.');
  }

  static String _string(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is String) return value;
    throw FormatException('Campo "$key" ausente o inválido.');
  }

  static DateTime _date(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    throw FormatException('Campo "$key" ausente o inválido.');
  }

  static PqrsType _type(Object? key) {
    for (final type in PqrsType.values) {
      if (type.name == key) return type;
    }
    throw FormatException('Tipo PQRS desconocido: $key');
  }
}
