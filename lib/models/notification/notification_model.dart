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

/// Modelo de estado. Los datos iniciales se cargan desde el controlador.
class NotificationModel {
  NotificationModel({List<AppNotification>? notifications})
    : notifications = notifications ?? [];

  List<AppNotification> notifications;
}
