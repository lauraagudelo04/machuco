import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:machuco/models/notification/notification_model.dart';
import 'package:machuco/service/firebase/firestore_collections.dart';

/// Firestore replica of the notification inbox. SQLite remains the offline
/// cache managed by [NotificationRepository]; this repository is the shared
/// transport between Firebase accounts/devices.
class NotificationCloudRepository {
  NotificationCloudRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  static const _requestTimeout = Duration(seconds: 10);

  CollectionReference<Map<String, dynamic>> get _notifications =>
      _firestore.collection(FirestoreCollections.notifications);

  Future<String> publishManual({
    required NotificationType type,
    required String title,
    required String message,
    required NotificationTarget target,
    required String actorUid,
    required String remoteId,
    String? recipientUid,
    String? recipientName,
    String? recipientEmail,
  }) async {
    // Firestore stores the stable event contract. The notification-type catalog
    // may contain extra admin labels (for example, "prueba222"), which are
    // presentation types rather than valid domain event types.
    final eventType = switch (type.code) {
      'reservation' || 'payment' || 'review' || 'system' => type.code,
      _ => 'system',
    };
    final document = _notifications.doc(remoteId);
    try {
      await _firestore
          .runTransaction((transaction) async {
            if ((await transaction.get(document)).exists) return;
            transaction.set(document, {
              'eventType': eventType,
              'actorUid': actorUid,
              'target': target.name,
              if (target == NotificationTarget.specificUser)
                'recipientUid': recipientUid,
              if (target == NotificationTarget.specificUser)
                'recipientName': recipientName,
              if (target == NotificationTarget.specificUser)
                'recipientEmail': recipientEmail,
              'title': title.trim(),
              'message': message.trim(),
              'createdAt': FieldValue.serverTimestamp(),
            });
          })
          .timeout(_requestTimeout);
    } on FirebaseException catch (error) {
      throw _map(error);
    } on TimeoutException {
      throw const NotificationCloudRepositoryException(
        NotificationCloudFailureType.network,
        'Sin conexión: la notificación quedó pendiente de publicación.',
      );
    }
    return document.id;
  }

  NotificationCloudRepositoryException _map(FirebaseException error) {
    debugPrint('Firestore notifications error: ${error.code}');
    return switch (error.code) {
      'permission-denied' ||
      'unauthenticated' => const NotificationCloudRepositoryException(
        NotificationCloudFailureType.permissionDenied,
        'No tienes permisos para publicar esta notificación.',
      ),
      'unavailable' ||
      'deadline-exceeded' => const NotificationCloudRepositoryException(
        NotificationCloudFailureType.network,
        'Sin conexión: la notificación quedó pendiente de publicación.',
      ),
      _ => const NotificationCloudRepositoryException(
        NotificationCloudFailureType.unknown,
        'No se pudo publicar la notificación. Inténtalo de nuevo.',
      ),
    };
  }

  /// Retrieves all documents visible to a role. Separate queries avoid an
  /// unsupported OR across `target` and `recipientUid` and work offline from
  /// Firestore's own cache as well.
  Future<List<CloudNotification>> findInbox({
    required String uid,
    required String role,
  }) async {
    final roleTarget = role == 'owner' ? 'owners' : 'clients';
    final results = await Future.wait([
      _notifications
          .where('target', whereIn: ['all', roleTarget])
          .limit(100)
          .get(),
      _notifications
          .where('target', isEqualTo: 'specificUser')
          .where('recipientUid', isEqualTo: uid)
          .limit(100)
          .get(),
    ]);
    final seen = <String>{};
    final notifications = <CloudNotification>[];
    for (final document in results.expand((snapshot) => snapshot.docs)) {
      if (seen.add(document.id)) {
        notifications.add(CloudNotification.fromDocument(document));
      }
    }
    notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return notifications;
  }

  Future<bool> isRead({
    required String uid,
    required String notificationId,
  }) async =>
      (await _firestore
              .collection(FirestoreCollections.users)
              .doc(uid)
              .collection('notificationReads')
              .doc(notificationId)
              .get())
          .exists;

  Future<void> markRead({
    required String uid,
    required String notificationId,
  }) => _firestore
      .collection(FirestoreCollections.users)
      .doc(uid)
      .collection('notificationReads')
      .doc(notificationId)
      .set({'readAt': FieldValue.serverTimestamp()});
}

enum NotificationCloudFailureType { permissionDenied, network, unknown }

class NotificationCloudRepositoryException implements Exception {
  const NotificationCloudRepositoryException(this.type, this.message);

  final NotificationCloudFailureType type;
  final String message;

  @override
  String toString() => message;
}

class CloudNotification {
  const CloudNotification({
    required this.id,
    required this.eventType,
    required this.title,
    required this.message,
    required this.target,
    required this.createdAt,
    this.recipientUid,
    this.recipientName,
    this.recipientEmail,
  });

  final String id;
  final String eventType;
  final String title;
  final String message;
  final NotificationTarget target;
  final DateTime createdAt;
  final String? recipientUid;
  final String? recipientName;
  final String? recipientEmail;

  factory CloudNotification.fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    return CloudNotification(
      id: document.id,
      eventType: data['eventType']?.toString() ?? 'system',
      title: data['title']?.toString() ?? '',
      message: data['message']?.toString() ?? '',
      target: NotificationTarget.values.byName(
        data['target']?.toString() ?? 'all',
      ),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      recipientUid: data['recipientUid']?.toString(),
      recipientName: data['recipientName']?.toString(),
      recipientEmail: data['recipientEmail']?.toString(),
    );
  }
}
