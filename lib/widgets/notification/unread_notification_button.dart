import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:machuco/controllers/notification/notification_controller.dart';
import 'package:machuco/core/design_system/components/app_icon_button.dart';
import 'package:machuco/core/design_system/tokens/app_colors.dart';

/// Access button that keeps the inbox count in sync with the same UID used by
/// the inbox itself. It is deliberately independent from the destination page
/// so returning from that page refreshes the visible badge automatically.
class UnreadNotificationButton extends StatefulWidget {
  const UnreadNotificationButton({
    super.key,
    required this.recipientRole,
    required this.onPressed,
  });

  final String recipientRole;
  final FutureOr<void> Function() onPressed;

  @override
  State<UnreadNotificationButton> createState() =>
      _UnreadNotificationButtonState();
}

class _UnreadNotificationButtonState extends State<UnreadNotificationButton> {
  late final NotificationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = NotificationController(
      recipientUid: FirebaseAuth.instance.currentUser?.uid,
      recipientRole: widget.recipientRole,
    )..addListener(_refresh);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_refresh)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final count = _controller.unreadCount;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        AppIconButton(
          icon: Icons.notifications_none_outlined,
          tooltip: count == 0 ? 'Notificaciones' : '$count sin leer',
          onPressed: () async {
            await widget.onPressed();
            await _controller.load();
          },
        ),
        if (count > 0)
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: AppColors.rose,
                shape: BoxShape.circle,
              ),
              child: Text(
                count > 99 ? '99+' : '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
