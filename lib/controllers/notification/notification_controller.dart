import 'package:flutter/material.dart';
import '../../models/notification/notification_model.dart';

/// Controlador en la arquitectura MVC
/// Modifica los datos del modelo y notifica a la vista mediante ChangeNotifier
class NotificationController extends ChangeNotifier {
  static final NotificationController _instance = NotificationController._internal();

  factory NotificationController() => _instance;

  NotificationController._internal();

  /// El controlador inicializa el objeto modelo que contiene los datos puros
  final NotificationModel _model = NotificationModel();

  List<AppNotification> get notifications => List.unmodifiable(_model.notifications);

  int get unreadCount => _model.notifications.where((n) => n.isUnread).length;

  List<AppNotification> getFilteredNotifications(NotificationType? filter) {
    if (filter == null) return notifications;
    return _model.notifications.where((n) => n.type == filter).toList();
  }

  void markAllRead() {
    _model.notifications = [
      for (final n in _model.notifications) n.copyWith(isUnread: false),
    ];
    notifyListeners();
  }

  void markAsRead(AppNotification notification) {
    if (!notification.isUnread) return;
    final index = _model.notifications.indexWhere((n) => n.id == notification.id);
    if (index != -1) {
      _model.notifications[index] = notification.copyWith(isUnread: false);
      notifyListeners();
    }
  }

  AppNotification addNotification({
    required NotificationType type,
    required String title,
    required String message,
    required NotificationTarget target,
    String? recipientUser,
  }) {
    final newNotification = AppNotification(
      id: 'notif-${DateTime.now().millisecondsSinceEpoch}',
      type: type,
      title: title,
      message: message,
      time: 'Justo ahora',
      isUnread: true,
      target: target,
      recipientUser: recipientUser,
    );

    _model.notifications.insert(0, newNotification);
    notifyListeners();
    return newNotification;
  }
}
