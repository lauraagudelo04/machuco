import 'package:flutter/material.dart';
import 'package:machuco/core/design_system/design_system.dart';

enum AuthNoticeTone { error, info }

/// Aviso en línea con icono y texto (el estado nunca depende solo del color),
/// con una acción opcional como "Reintentar".
class AuthNotice extends StatelessWidget {
  const AuthNotice({
    super.key,
    required this.message,
    this.tone = AuthNoticeTone.error,
    this.icon,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final AuthNoticeTone tone;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isError = tone == AuthNoticeTone.error;
    final color = isError ? scheme.error : scheme.primary;
    final resolvedIcon =
        icon ?? (isError ? Icons.error_outline : Icons.info_outline);
    return Semantics(
      liveRegion: true,
      container: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: context.appColors.elevated,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: color),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(resolvedIcon, color: color),
              const SizedBox(width: AppSpacing.s2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      message,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    if (actionLabel != null && onAction != null)
                      TextButton(
                        onPressed: onAction,
                        style: TextButton.styleFrom(
                          minimumSize: const Size(48, 48),
                        ),
                        child: Text(actionLabel!),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
