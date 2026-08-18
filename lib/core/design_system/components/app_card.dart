import 'package:flutter/material.dart';
import '../theme/app_theme_extensions.dart';
import '../tokens/app_colors.dart';
import '../tokens/app_radius.dart';
import '../tokens/app_spacing.dart';

class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child, this.onTap, this.selected = false, this.padding = const EdgeInsets.all(AppSpacing.s4), this.semanticLabel});
  final Widget child; final VoidCallback? onTap; final bool selected; final EdgeInsetsGeometry padding; final String? semanticLabel;
  @override Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.lg);
    return Semantics(button: onTap != null, selected: selected, label: semanticLabel, child: Material(
      color: selected ? AppColors.violet.withValues(alpha: .10) : Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: radius, side: BorderSide(color: selected ? AppColors.violet : context.appColors.border)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, borderRadius: radius, child: Padding(padding: padding, child: child)),
    ));
  }
}
