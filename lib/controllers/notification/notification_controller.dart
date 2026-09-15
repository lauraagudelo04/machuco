import 'package:flutter/material.dart';
import '../../models/notification/notification_model.dart';

/// Controlador en la arquitectura MVC
/// Modifica los datos del modelo y notifica a la vista mediante ChangeNotifier
class NotificationController extends ChangeNotifier {
  static final NotificationController _instance =
      NotificationController._internal();

  factory NotificationController() => _instance;

  NotificationController._internal()
    : _model = NotificationModel(notifications: _initialNotifications);

  static const demoClientUser = 'laura@machuco.com';
  static const demoOwnerUser = 'owner-1020304050';

  /// Data mockeada del modulo. Vive en el controlador para que el modelo
  /// conserve solo la estructura y el estado.
  static final List<AppNotification> _initialNotifications = [
    const AppNotification(
      id: 'notif-1',
      type: NotificationType.reservation,
      title: 'Reserva confirmada',
      message:
          'Tu reserva en Motel El Paraíso quedó confirmada para hoy a las 3:00 PM.',
      time: 'hace 5 min',
      isUnread: true,
      target: NotificationTarget.specificUser,
      recipientUser: demoClientUser,
    ),
    const AppNotification(
      id: 'notif-2',
      type: NotificationType.payment,
      title: 'Pago recibido',
      message: 'Recibimos tu pago de \$120.000 por la reserva #4821.',
      time: 'hace 1 h',
      isUnread: true,
      target: NotificationTarget.specificUser,
      recipientUser: demoClientUser,
    ),
    const AppNotification(
      id: 'notif-3',
      type: NotificationType.review,
      title: 'Nueva reseña',
      message:
          'Tu huésped dejó una reseña de 5 estrellas en la habitación Estándar.',
      time: 'hace 3 h',
      target: NotificationTarget.specificUser,
      recipientUser: demoOwnerUser,
    ),
    const AppNotification(
      id: 'notif-4',
      type: NotificationType.system,
      title: 'Mantenimiento programado',
      message:
          'El próximo martes se hará mantenimiento en las habitaciones 2 y 3.',
      time: 'ayer',
      target: NotificationTarget.all,
    ),
    const AppNotification(
      id: 'notif-5',
      type: NotificationType.reservation,
      title: 'Recordatorio de check-in',
      message: 'Tu check-in en Motel Suites Central es hoy a las 3:00 PM.',
      time: 'hace 2 días',
      target: NotificationTarget.specificUser,
      recipientUser: 'camilo@machuco.com',
    ),
  ];

  final NotificationModel _model;

  List<AppNotification> get notifications =>
      List.unmodifiable(_model.notifications);

  int get unreadCount => _model.notifications.where((n) => n.isUnread).length;

  int receivedUnreadCount(String recipientUser) => getReceivedNotifications(
    recipientUser: recipientUser,
  ).where((n) => n.isUnread).length;

  List<AppNotification> getFilteredNotifications(NotificationType? filter) {
    if (filter == null) return notifications;
    return _model.notifications.where((n) => n.type == filter).toList();
  }

  List<AppNotification> getReceivedNotifications({
    required String recipientUser,
    NotificationType? filter,
  }) {
    final normalizedRecipient = recipientUser.trim().toLowerCase();
    return _model.notifications.where((notification) {
      final isForEveryone = notification.target == NotificationTarget.all;
      final isForRecipient =
          notification.recipientUser?.trim().toLowerCase() ==
          normalizedRecipient;
      final matchesType = filter == null || notification.type == filter;
      return (isForEveryone || isForRecipient) && matchesType;
    }).toList();
  }

  void markAllRead() {
    _model.notifications = [
      for (final n in _model.notifications) n.copyWith(isUnread: false),
    ];
    notifyListeners();
  }

  void markReceivedAsRead(String recipientUser) {
    final visibleIds = getReceivedNotifications(
      recipientUser: recipientUser,
    ).map((n) => n.id).toSet();
    _model.notifications = [
      for (final n in _model.notifications)
        visibleIds.contains(n.id) ? n.copyWith(isUnread: false) : n,
    ];
    notifyListeners();
  }

  void markAsRead(AppNotification notification) {
    if (!notification.isUnread) return;
    final index = _model.notifications.indexWhere(
      (n) => n.id == notification.id,
    );
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
