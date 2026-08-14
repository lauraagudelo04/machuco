import 'package:flutter/material.dart';
import '../theme/app_theme_extensions.dart';
import '../tokens/app_colors.dart';

enum AppIconButtonVariant { standard, overlay, destructive }

class AppIconButton extends StatelessWidget {
  const AppIconButton({super.key, required this.icon, required this.tooltip, required this.onPressed, this.variant = AppIconButtonVariant.standard});
  final IconData icon; final String tooltip; final VoidCallback? onPressed; final AppIconButtonVariant variant;
  @override Widget build(BuildContext context) => IconButton(
    tooltip: tooltip, onPressed: onPressed, icon: Icon(icon),
    style: IconButton.styleFrom(
      minimumSize: const Size.square(48),
      foregroundColor: variant == AppIconButtonVariant.destructive ? AppColors.rose : variant == AppIconButtonVariant.overlay ? Colors.white : Theme.of(context).colorScheme.onSurface,
      backgroundColor: variant == AppIconButtonVariant.overlay ? Colors.black.withValues(alpha: .38) : context.appColors.elevated,
    ),
  );
}
