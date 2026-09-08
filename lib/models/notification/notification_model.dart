import 'package:flutter/material.dart';
import '../../core/design_system/tokens/app_colors.dart';

enum NotificationType { reservation, payment, review, system }

extension NotificationTypeData on NotificationType {
  String get label => switch (this) {
        NotificationType.reservation => 'Reservas',
        NotificationType.payment => 'Pagos',
        NotificationType.review => 'Reseñas',
        NotificationType.system => 'Sistema',
      };

  IconData get icon => switch (this) {
        NotificationType.reservation => Icons.event_outlined,
        NotificationType.payment => Icons.payments_outlined,
        NotificationType.review => Icons.star_outline,
        NotificationType.system => Icons.campaign_outlined,
      };

  Color get color => switch (this) {
        NotificationType.reservation => AppColors.violet,
        NotificationType.payment => AppColors.available,
        NotificationType.review => AppColors.fuchsia,
        NotificationType.system => AppColors.purple,
      };
}

enum NotificationTarget { all, specificUser }

extension NotificationTargetData on NotificationTarget {
  String get label => switch (this) {
        NotificationTarget.all => 'Todos los usuarios',
        NotificationTarget.specificUser => 'Usuario específico',
      };
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.time,
    this.isUnread = false,
    this.target = NotificationTarget.all,
    this.recipientUser,
  });

  final String id;
  final NotificationType type;
  final String title;
  final String message;
  final String time;
  final bool isUnread;
  final NotificationTarget target;
  final String? recipientUser;

  AppNotification copyWith({
    bool? isUnread,
    NotificationType? type,
    String? title,
    String? message,
    String? time,
    NotificationTarget? target,
    String? recipientUser,
  }) {
    return AppNotification(
      id: id,
      type: type ?? this.type,
      title: title ?? this.title,
      message: message ?? this.message,
      time: time ?? this.time,
      isUnread: isUnread ?? this.isUnread,
      target: target ?? this.target,
      recipientUser: recipientUser ?? this.recipientUser,
    );
  }
}

/// Clase Modelo que contiene los datos puros de las notificaciones
class NotificationModel {
  List<AppNotification> notifications = [
    const AppNotification(
      id: 'notif-1',
      type: NotificationType.reservation,
      title: 'Reserva confirmada',
      message:
          'Tu reserva en Motel El Paraíso quedó confirmada para hoy a las 3:00 PM.',
      time: 'hace 5 min',
      isUnread: true,
      target: NotificationTarget.specificUser,
      recipientUser: 'laura@machuco.com',
    ),
    const AppNotification(
      id: 'notif-2',
      type: NotificationType.payment,
      title: 'Pago recibido',
      message: 'Recibimos tu pago de \$120.000 por la reserva #4821.',
      time: 'hace 1 h',
      isUnread: true,
      target: NotificationTarget.specificUser,
      recipientUser: 'laura@machuco.com',
    ),
    const AppNotification(
      id: 'notif-3',
      type: NotificationType.review,
      title: 'Nueva reseña',
      message:
          'Tu huésped dejó una reseña de 5 estrellas en la habitación Estándar.',
      time: 'hace 3 h',
      target: NotificationTarget.all,
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
}
