import 'package:flutter/material.dart';
import '../theme/app_theme_extensions.dart';
import '../tokens/app_colors.dart';
import '../tokens/app_gradients.dart';
import '../tokens/app_motion.dart';
import '../tokens/app_radius.dart';
import '../tokens/app_shadows.dart';
import '../tokens/app_spacing.dart';

enum AppButtonVariant { primary, secondary, destructive }
enum AppButtonSize { medium, large }

class AppButton extends StatefulWidget {
  const AppButton({super.key, required this.label, required this.onPressed, this.variant = AppButtonVariant.primary, this.size = AppButtonSize.large, this.loading = false, this.icon, this.expanded = true});
  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final AppButtonSize size;
  final bool loading;
  final IconData? icon;
  final bool expanded;

  @override State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  bool pressed = false;
  @override Widget build(BuildContext context) {
    final enabled = widget.onPressed != null && !widget.loading;
    final height = widget.size == AppButtonSize.large ? 52.0 : 48.0;
    final semanticsLabel = widget.loading ? '${widget.label}, cargando' : widget.label;
    final foreground = widget.variant == AppButtonVariant.destructive ? AppColors.rose : Theme.of(context).colorScheme.onSurface;
    final content = AnimatedSwitcher(
      duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : AppMotion.fast,
      child: widget.loading
          ? SizedBox(key: const ValueKey('loading'), width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: widget.variant == AppButtonVariant.primary ? Colors.white : foreground))
          : Row(key: const ValueKey('label'), mainAxisSize: MainAxisSize.min, children: [if (widget.icon case final icon?) ...[Icon(icon, size: 20), const SizedBox(width: AppSpacing.s2)], Text(widget.label)]),
    );
    return Semantics(button: true, enabled: enabled, label: semanticsLabel, child: AnimatedScale(
      scale: pressed && enabled ? .97 : 1,
      duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : AppMotion.fast,
      child: SizedBox(width: widget.expanded ? double.infinity : null, height: height, child: ConstrainedBox(constraints: const BoxConstraints(minWidth: 48), child: Material(
        color: Colors.transparent,
        child: Ink(decoration: BoxDecoration(
          gradient: enabled && widget.variant == AppButtonVariant.primary ? AppGradients.primary : null,
          color: !enabled ? context.appColors.elevated : widget.variant == AppButtonVariant.secondary ? context.appColors.elevated : widget.variant == AppButtonVariant.destructive ? AppColors.rose.withValues(alpha: .12) : null,
          borderRadius: BorderRadius.circular(AppRadius.lg), boxShadow: enabled && widget.variant == AppButtonVariant.primary ? AppShadows.cta : null,
          border: widget.variant == AppButtonVariant.secondary ? Border.all(color: context.appColors.borderStrong) : null,
        ), child: InkWell(
          onTap: enabled ? widget.onPressed : null, onHighlightChanged: (value) => setState(() => pressed = value), borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Padding(padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s5), child: Center(widthFactor: widget.expanded ? null : 1, child: DefaultTextStyle(style: Theme.of(context).textTheme.labelLarge!.copyWith(color: !enabled ? context.appColors.textDisabled : widget.variant == AppButtonVariant.primary ? Colors.white : foreground), child: IconTheme(data: IconThemeData(color: !enabled ? context.appColors.textDisabled : widget.variant == AppButtonVariant.primary ? Colors.white : foreground), child: content)))),
        )),
      ))),
    ));
  }
}
