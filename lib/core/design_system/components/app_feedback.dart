import 'package:flutter/material.dart';
import '../theme/app_theme_extensions.dart';
import '../tokens/app_spacing.dart';
import 'app_button.dart';

class AppEmptyState extends StatelessWidget {
  const AppEmptyState({super.key, required this.icon, required this.title, required this.message, this.actionLabel, this.onAction});
  final IconData icon; final String title; final String message; final String? actionLabel; final VoidCallback? onAction;
  @override Widget build(BuildContext context) => _FeedbackState(icon: icon, title: title, message: message, actionLabel: actionLabel, onAction: onAction);
}

class AppErrorState extends StatelessWidget {
  const AppErrorState({super.key, required this.message, this.onRetry, this.code});
  final String message; final VoidCallback? onRetry; final String? code;
  @override Widget build(BuildContext context) => _FeedbackState(icon: Icons.error_outline, title: 'Algo salió mal', message: message, detail: code == null ? null : 'Código: $code', actionLabel: onRetry == null ? null : 'Reintentar', onAction: onRetry);
}

class _FeedbackState extends StatelessWidget {
  const _FeedbackState({required this.icon, required this.title, required this.message, this.detail, this.actionLabel, this.onAction});
  final IconData icon; final String title; final String message; final String? detail; final String? actionLabel; final VoidCallback? onAction;
  @override Widget build(BuildContext context) => Semantics(liveRegion: true, child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 420), child: Padding(padding: const EdgeInsets.all(AppSpacing.s5), child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 48, color: Theme.of(context).colorScheme.primary), const SizedBox(height: AppSpacing.s4), Text(title, style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center), const SizedBox(height: AppSpacing.s2), Text(message, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: context.appColors.textSecondary), textAlign: TextAlign.center), if (detail case final value?) ...[const SizedBox(height: AppSpacing.s1), Text(value, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: context.appColors.textMuted))], if (actionLabel case final label?) ...[const SizedBox(height: AppSpacing.s5), AppButton(label: label, onPressed: onAction, expanded: false)] ])))));
}
