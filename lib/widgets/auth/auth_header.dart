import 'package:flutter/material.dart';
import 'package:machuco/core/design_system/design_system.dart';

/// Logo y título de las pantallas de autenticación.
class AuthHeader extends StatelessWidget {
  const AuthHeader({super.key, required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CircleAvatar(
          radius: AppSpacing.s6 + AppSpacing.s2 / 2,
          backgroundColor: Theme.of(context).colorScheme.primary,
          child: const Icon(
            Icons.bed_rounded,
            color: Colors.white,
            size: AppSpacing.s6 + AppSpacing.s1,
          ),
        ),
        const SizedBox(height: AppSpacing.s2),
        Text(
          title,
          style: Theme.of(context).textTheme.headlineMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.s1),
        Text(
          subtitle,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: context.appColors.textMuted),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
