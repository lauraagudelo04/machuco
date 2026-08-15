import 'package:flutter/material.dart';

@immutable
final class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  const AppSemanticColors({
    required this.canvas,
    required this.elevated,
    required this.mediaFallback,
    required this.textSecondary,
    required this.textMuted,
    required this.textDisabled,
    required this.border,
    required this.borderStrong,
  });

  final Color canvas;
  final Color elevated;
  final Color mediaFallback;
  final Color textSecondary;
  final Color textMuted;
  final Color textDisabled;
  final Color border;
  final Color borderStrong;

  @override
  AppSemanticColors copyWith({Color? canvas, Color? elevated, Color? mediaFallback, Color? textSecondary, Color? textMuted, Color? textDisabled, Color? border, Color? borderStrong}) => AppSemanticColors(
    canvas: canvas ?? this.canvas,
    elevated: elevated ?? this.elevated,
    mediaFallback: mediaFallback ?? this.mediaFallback,
    textSecondary: textSecondary ?? this.textSecondary,
    textMuted: textMuted ?? this.textMuted,
    textDisabled: textDisabled ?? this.textDisabled,
    border: border ?? this.border,
    borderStrong: borderStrong ?? this.borderStrong,
  );

  @override
  AppSemanticColors lerp(covariant AppSemanticColors? other, double t) {
    if (other == null) return this;
    return AppSemanticColors(
      canvas: Color.lerp(canvas, other.canvas, t)!, elevated: Color.lerp(elevated, other.elevated, t)!,
      mediaFallback: Color.lerp(mediaFallback, other.mediaFallback, t)!, textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!, textDisabled: Color.lerp(textDisabled, other.textDisabled, t)!,
      border: Color.lerp(border, other.border, t)!, borderStrong: Color.lerp(borderStrong, other.borderStrong, t)!,
    );
  }
}

extension AppThemeContext on BuildContext {
  AppSemanticColors get appColors => Theme.of(this).extension<AppSemanticColors>()!;
}
