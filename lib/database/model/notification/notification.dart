import 'package:floor/floor.dart';

@Entity(tableName: 'notifications')
class NotificationEntry {
  const NotificationEntry({
    this.id,
    required this.typeId,
    required this.title,
    required this.message,
    required this.sentAt,
    required this.target,
    this.recipientUser,
  });

  @PrimaryKey(autoGenerate: true)
  final int? id;
  final int typeId;
  final String title;
  final String message;
  final DateTime sentAt;
  final String target;
  final String? recipientUser;
}

@Entity(
  tableName: 'notification_reads',
  foreignKeys: [
    ForeignKey(
      childColumns: ['notificationId'],
      parentColumns: ['id'],
      entity: NotificationEntry,
    ),
  ],
  indices: [
    Index(value: ['notificationId', 'userId'], unique: true),
  ],
)
class NotificationRead {
  const NotificationRead({
    this.id,
    required this.notificationId,
    required this.userId,
    required this.readAt,
  });

  @PrimaryKey(autoGenerate: true)
  final int? id;
  final int notificationId;
  final String userId;
  final DateTime readAt;
}
