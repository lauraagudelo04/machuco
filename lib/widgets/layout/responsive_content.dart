import 'package:flutter/material.dart';
import 'package:machuco/core/design_system/design_system.dart';

class ResponsiveContent extends StatelessWidget {
  const ResponsiveContent({
    super.key,
    required this.child,
    this.maxWidth = 1120,
    this.padding,
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontal = constraints.maxWidth < 600
            ? AppSpacing.screenCompact
            : AppSpacing.s6;
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Padding(
              padding:
                  padding ??
                  EdgeInsets.fromLTRB(
                    horizontal,
                    AppSpacing.s4,
                    horizontal,
                    AppSpacing.s8,
                  ),
              child: child,
            ),
          ),
        );
      },
    );
  }
}

class ResponsiveSplit extends StatelessWidget {
  const ResponsiveSplit({
    super.key,
    required this.primary,
    required this.secondary,
    this.breakpoint = 820,
    this.secondaryWidth = 340,
  });

  final Widget primary;
  final Widget secondary;
  final double breakpoint;
  final double secondaryWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < breakpoint) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              primary,
              const SizedBox(height: AppSpacing.s4),
              secondary,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: primary),
            const SizedBox(width: AppSpacing.s5),
            SizedBox(width: secondaryWidth, child: secondary),
          ],
        );
      },
    );
  }
}
