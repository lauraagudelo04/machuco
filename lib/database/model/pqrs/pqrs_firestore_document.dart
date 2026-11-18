import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:machuco/database/repository/pqrs/pqrs_repository.dart';
import 'package:machuco/models/pqrs/pqrs.dart';

/// Id of the trace entry written together with a new request. It carries the
/// photos attached when the request was opened.
String pqrsOpeningTraceId(String requestId) => '$requestId-open';

/// Id of the [position]-th (1 to 3) photo of a trace entry. The fixed suffix
/// lets `firestore.rules` limit the photos per entry.
String pqrsPhotoId(String traceId, int position) => '${traceId}_$position';

/// Mapping between the PQRS domain model and its Firestore documents
/// (`pqrs/{id}`, `pqrs/{id}/traces/{id}` and `pqrs/{id}/photos/{id}`).
///
/// Pure functions: no Firestore instance is needed, so they are unit tested.
/// Writers use `FieldValue` placeholders for the server-controlled instants
/// (`createdAt`, `updatedAt`, `resolvedAt`) and readers throw
/// [FormatException] when a document is malformed.
abstract final class PqrsFirestoreDocument {
  // ------------------------------------------------------------ status keys

  /// Value stored in `status` (`in_progress`, not `inProgress`).
  static String statusToKey(PqrsStatus status) => switch (status) {
    PqrsStatus.pending => 'pending',
    PqrsStatus.inProgress => 'in_progress',
    PqrsStatus.resolved => 'resolved',
    PqrsStatus.closed => 'closed',
    PqrsStatus.rejected => 'rejected',
  };

  static PqrsStatus statusFromKey(Object? key) {
    for (final status in PqrsStatus.values) {
      if (statusToKey(status) == key) return status;
    }
    throw FormatException('Estado PQRS desconocido: $key');
  }

  static String actorToKey(PqrsActor actor) => switch (actor) {
    PqrsActor.client => 'client',
    PqrsActor.owner => 'owner',
    PqrsActor.systemAdmin => 'systemAdmin',
  };

  static PqrsActor actorFromKey(Object? key) {
    for (final actor in PqrsActor.values) {
      if (actorToKey(actor) == key) return actor;
    }
    throw FormatException('Rol PQRS desconocido: $key');
  }

  // ---------------------------------------------------------------- writers

  /// `pqrs/{id}` for a new request. `ownerId` is the one read from
  /// `motels/{motelId}`, not the one the caller supplied.
  static Map<String, Object?> newRequestToFirestore(
    PqrsNewRequest request, {
    required String ownerId,
  }) => {
    'clientId': request.clientId,
    'clientName': request.clientName,
    'motelId': request.motelId,
    'motelName': request.motelName,
    'ownerId': ownerId,
    'type': request.type.name,
    'subject': request.subject,
    'description': request.description,
    'status': statusToKey(PqrsStatus.pending),
    'photoCount': request.photos.length,
    'createdAt': FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
  };

  /// Changes to apply to `pqrs/{id}` for an action, or `null` when the action
  /// does not change the document (a comment without status change).
  ///
  /// Only `status`, `updatedAt`, `resolvedAt` and `closedBy` are ever written,
  /// matching the update rule.
  static Map<String, Object?>? updateToFirestore(PqrsTraceAppend action) {
    final change = action.entry.statusChange;
    if (change == null) return null;
    return {
      'status': statusToKey(change),
      'updatedAt': FieldValue.serverTimestamp(),
      if (action.resolvedAt != null)
        'resolvedAt': FieldValue.serverTimestamp()
      else if (action.clearResolvedAt)
        'resolvedAt': FieldValue.delete(),
      if (action.closedBy != null) 'closedBy': action.closedBy!.key,
    };
  }

  /// `pqrs/{id}/traces/{traceId}`.
  static Map<String, Object?> traceToFirestore(PqrsTraceEntry entry) => {
    'authorId': entry.authorId,
    'authorRole': actorToKey(entry.author),
    'authorName': _authorName(entry),
    'message': entry.message,
    if (entry.statusChange != null)
      'statusChange': statusToKey(entry.statusChange!),
    'photoCount': storablePhotos(entry.attachments).length,
    'createdAt': FieldValue.serverTimestamp(),
  };

  /// `pqrs/{id}/photos/{photoId}`. [attachment] must have an image.
  static Map<String, Object?> photoToFirestore(
    PqrsAttachment attachment, {
    required String traceId,
    required String authorId,
    required PqrsActor authorRole,
  }) {
    final bytes = attachment.bytes;
    final mimeType = attachment.mimeType;
    if (bytes == null || mimeType == null) {
      throw const FormatException('La foto no tiene imagen para guardar.');
    }
    return {
      'bytes': Blob(bytes),
      'mimeType': mimeType,
      'traceId': traceId,
      'authorId': authorId,
      'authorRole': actorToKey(authorRole),
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  /// Attachments that carry a real image (simulated ones are never stored).
  static List<PqrsAttachment> storablePhotos(List<PqrsAttachment> photos) =>
      photos.where((photo) => photo.hasImage).toList(growable: false);

  // ---------------------------------------------------------------- readers

  /// Builds a request from `pqrs/{id}`. [trace] and [attachments] come from
  /// the subcollections.
  static PqrsRequest requestFromFirestore(
    String id,
    Map<String, dynamic> data, {
    List<PqrsTraceEntry> trace = const [],
    List<PqrsAttachment> attachments = const [],
  }) {
    final type = _type(data['type']);
    return PqrsRequest(
      id: id,
      motelId: _string(data, 'motelId'),
      motelName: _string(data, 'motelName'),
      clientId: _string(data, 'clientId'),
      clientName: _string(data, 'clientName'),
      ownerId: _string(data, 'ownerId'),
      type: type,
      subject: _string(data, 'subject'),
      description: _string(data, 'description'),
      createdAt: _date(data, 'createdAt'),
      status: statusFromKey(data['status']),
      resolvedAt: _optionalDate(data['resolvedAt']),
      // Absent or unknown: counted as a client closure by the statistics.
      closedBy: PqrsClosedBy.fromKey(data['closedBy'] as String?),
      trace: trace,
      attachments: attachments,
    );
  }

  static PqrsTraceEntry traceFromFirestore(
    String id,
    Map<String, dynamic> data, {
    List<PqrsAttachment> attachments = const [],
  }) {
    final change = data['statusChange'];
    return PqrsTraceEntry(
      id: id,
      author: actorFromKey(data['authorRole']),
      authorId: _string(data, 'authorId'),
      authorName: data['authorName'] as String? ?? '',
      message: _string(data, 'message'),
      createdAt: _date(data, 'createdAt'),
      attachments: attachments,
      statusChange: change == null ? null : statusFromKey(change),
    );
  }

  static PqrsAttachment photoFromFirestore(
    String id,
    Map<String, dynamic> data,
    int position,
  ) {
    final raw = data['bytes'];
    if (raw is! Blob) {
      throw const FormatException('La foto no tiene bytes.');
    }
    final Uint8List bytes = raw.bytes;
    return PqrsAttachment(
      id: id,
      label: 'Foto $position',
      author: actorFromKey(data['authorRole']),
      capturedAt: _date(data, 'createdAt'),
      seed: 0,
      bytes: bytes,
      mimeType: _string(data, 'mimeType'),
    );
  }

  // ---------------------------------------------------------------- helpers

  static String _authorName(PqrsTraceEntry entry) {
    return entry.authorName.isEmpty
        ? (entry.author == PqrsActor.owner ? 'Propietario' : 'Cliente')
        : entry.authorName;
  }

  static PqrsType _type(Object? key) {
    for (final type in PqrsType.values) {
      if (type.name == key) return type;
    }
    throw FormatException('Tipo PQRS desconocido: $key');
  }

  static String _string(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value is String) return value;
    throw FormatException('Campo "$key" ausente o inválido.');
  }

  static DateTime _date(Map<String, dynamic> data, String key) {
    final value = _optionalDate(data[key]);
    if (value == null) throw FormatException('Campo "$key" ausente.');
    return value;
  }

  static DateTime? _optionalDate(Object? value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    throw const FormatException('Fecha inválida.');
  }
}
