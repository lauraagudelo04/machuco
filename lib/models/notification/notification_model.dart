import 'package:flutter/material.dart';

import '../../core/design_system/tokens/app_colors.dart';

class NotificationType {
  const NotificationType({
    required this.id,
    required this.code,
    required this.name,
    this.description,
  });

  final int id;
  final String code;
  final String name;
  final String? description;

  factory NotificationType.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final code = json['code'];
    final name = json['name'];
    if (id is! int ||
        code is! String ||
        code.trim().isEmpty ||
        name is! String ||
        name.trim().isEmpty) {
      throw const FormatException('Tipo de notificación inválido');
    }
    final description = json['description'];
    if (description != null && description is! String) {
      throw const FormatException('Tipo de notificación inválido');
    }
    return NotificationType(
      id: id,
      code: code.trim(),
      name: name.trim(),
      description: description?.trim(),
    );
  }
}

extension NotificationTypePresentation on NotificationType {
  IconData get icon => switch (code) {
    'reservation' => Icons.event_outlined,
    'payment' => Icons.payments_outlined,
    'review' => Icons.star_outline,
    'system' => Icons.campaign_outlined,
    _ => Icons.notifications_outlined,
  };

  Color get color => switch (code) {
    'reservation' => AppColors.violet,
    'payment' => AppColors.available,
    'review' => AppColors.fuchsia,
    'system' => AppColors.purple,
    _ => AppColors.violet,
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
    required this.typeId,
    required this.title,
    required this.message,
    required this.sentAt,
    required this.isUnread,
    required this.target,
    this.type,
    this.recipientUser,
  });

  final int id;
  final int typeId;
  final NotificationType? type;
  final String title;
  final String message;
  final DateTime sentAt;
  final bool isUnread;
  final NotificationTarget target;
  final String? recipientUser;
}
