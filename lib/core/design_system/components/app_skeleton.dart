import 'package:flutter/material.dart';
import '../theme/app_theme_extensions.dart';
import '../tokens/app_motion.dart';
import '../tokens/app_radius.dart';

class AppSkeleton extends StatefulWidget {
  const AppSkeleton({super.key, this.width = double.infinity, required this.height, this.borderRadius = AppRadius.md});
  final double width; final double height; final double borderRadius;
  @override State<AppSkeleton> createState() => _AppSkeletonState();
}
class _AppSkeletonState extends State<AppSkeleton> with SingleTickerProviderStateMixin {
  late final AnimationController controller;
  @override void initState() { super.initState(); controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true); }
  @override void dispose() { controller.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) {
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    return Semantics(label: 'Cargando', container: true, child: ExcludeSemantics(child: reducedMotion ? _box(context, .65) : FadeTransition(opacity: Tween(begin: .45, end: .80).animate(CurvedAnimation(parent: controller, curve: AppMotion.standard)), child: _box(context, 1))));
  }
  Widget _box(BuildContext context, double opacity) => Container(width: widget.width, height: widget.height, decoration: BoxDecoration(color: context.appColors.mediaFallback.withValues(alpha: opacity), borderRadius: BorderRadius.circular(widget.borderRadius)));
}
