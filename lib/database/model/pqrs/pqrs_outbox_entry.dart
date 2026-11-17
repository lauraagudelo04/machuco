import 'dart:typed_data';

import 'package:floor/floor.dart';

/// Actions the outbox can hold.
abstract final class PqrsOutboxAction {
  static const create = 'create';
  static const comment = 'comment';
  static const advance = 'advance';
  static const resolve = 'resolve';
  static const reject = 'reject';
  static const close = 'close';
}

/// Local-only synchronization states. They are never written to Firestore.
abstract final class PqrsOutboxStatus {
  static const pendingSync = 'pending_sync';
  static const failed = 'failed';
}

/// Queue of actions not yet confirmed by Firestore. A row is deleted when the
/// batch is confirmed (the `synced` state is the absence of the row).
@Entity(
  tableName: 'pqrs_outbox',
  indices: [
    Index(value: ['pqrsId']),
    Index(value: ['syncStatus']),
  ],
)
class PqrsOutboxEntry {
  const PqrsOutboxEntry({
    required this.id,
    required this.pqrsId,
    required this.action,
    required this.payload,
    required this.syncStatus,
    required this.createdAt,
    this.errorMessage,
    this.attempts = 0,
  });

  /// The `traceId` generated on the client, so a retry reuses the same ids.
  @PrimaryKey()
  final String id;
  final String pqrsId;

  /// One of [PqrsOutboxAction].
  final String action;

  /// JSON with the document and the trace to send. It never carries photos.
  final String payload;

  /// One of [PqrsOutboxStatus].
  final String syncStatus;
  final String? errorMessage;
  final int createdAt;
  final int attempts;
}

/// One photo of a queued action, in its own row (at most 900 KB): a row above
/// ~2 MB fails to read on Android because of the sqflite cursor window.
@Entity(
  tableName: 'pqrs_outbox_photo',
  indices: [
    Index(value: ['outboxId']),
  ],
  foreignKeys: [
    ForeignKey(
      childColumns: ['outboxId'],
      parentColumns: ['id'],
      entity: PqrsOutboxEntry,
      onDelete: ForeignKeyAction.cascade,
    ),
  ],
)
class PqrsOutboxPhotoEntry {
  const PqrsOutboxPhotoEntry({
    required this.id,
    required this.outboxId,
    required this.mimeType,
    required this.bytes,
  });

  /// `<traceId>_1` to `<traceId>_10`.
  @PrimaryKey()
  final String id;
  final String outboxId;
  final String mimeType;
  final Uint8List bytes;
}
