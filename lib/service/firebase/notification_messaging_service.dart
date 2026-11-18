import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:machuco/service/firebase/firestore_collections.dart';
import 'package:machuco/views/notification/client_view/client_notification_view.dart';

/// FCM device registration and foreground presentation. Sending pushes from
/// Firestore is deliberately not attempted here: with Spark, test messages are
/// sent manually from Firebase Console to a registered device token.
class NotificationMessagingService {
  NotificationMessagingService({
    FirebaseMessaging? messaging,
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    this.navigatorKey,
  }) : _messaging = messaging ?? FirebaseMessaging.instance,
       _auth = auth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseMessaging _messaging;
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final GlobalKey<NavigatorState>? navigatorKey;
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();
  StreamSubscription<User?>? _authSubscription;

  Future<void> initialize() async {
    const initialization = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _local.initialize(
      settings: initialization,
      onDidReceiveNotificationResponse: (_) => _openInbox(),
    );
    await _messaging.requestPermission();
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
    FirebaseMessaging.onMessage.listen(_showForegroundNotification);
    FirebaseMessaging.onMessageOpenedApp.listen(_openInboxFromMessage);
    _messaging.onRegistered.listen(_saveToken);
    _authSubscription ??= _auth.authStateChanges().listen((user) {
      if (user != null) _messaging.register();
    });
    final user = _auth.currentUser;
    if (user != null) await _messaging.register();
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) _openInboxFromMessage(initialMessage);
  }

  Future<void> _saveToken(String token, {String? uid}) async {
    final ownerUid = uid ?? _auth.currentUser?.uid;
    if (ownerUid == null) return;
    await _firestore
        .collection(FirestoreCollections.users)
        .doc(ownerUid)
        .collection('devices')
        .doc(token)
        .set({
          'token': token,
          'updatedAt': FieldValue.serverTimestamp(),
          'platform': 'android',
        });
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    await _local.show(
      id: message.messageId?.hashCode ?? DateTime.now().millisecondsSinceEpoch,
      title:
          notification?.title ??
          message.data['title']?.toString() ??
          'Notificación',
      body: notification?.body ?? message.data['message']?.toString() ?? '',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'machuco_notifications',
          'Notificaciones MACHUCO',
          channelDescription: 'Avisos de reservas, pagos y sistema',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      payload: message.data['notificationId']?.toString(),
    );
  }

  void _openInboxFromMessage(RemoteMessage message) =>
      _openInbox(role: message.data['recipientRole']?.toString());

  void _openInbox({String? role}) {
    final navigator = navigatorKey?.currentState;
    if (navigator == null) return;
    navigator.push(
      MaterialPageRoute(
        builder: (_) => ClientNotificationView(
          recipientRole: role == 'owner' ? 'owner' : 'client',
        ),
      ),
    );
  }

  Future<void> dispose() async => _authSubscription?.cancel();
}
