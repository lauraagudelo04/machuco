import 'package:flutter/material.dart';
import '../tokens/app_colors.dart';

abstract final class AppColorScheme {
  static final ColorScheme light = _create(Brightness.light, AppLightColors.surface, AppLightColors.textPrimary);
  static final ColorScheme dark = _create(Brightness.dark, AppDarkColors.surface, AppDarkColors.textPrimary);

  static ColorScheme _create(Brightness brightness, Color surface, Color onSurface) => ColorScheme.fromSeed(
    seedColor: AppColors.violet,
    brightness: brightness,
  ).copyWith(
    primary: AppColors.violet, onPrimary: Colors.white,
    secondary: AppColors.purple, onSecondary: Colors.white,
    tertiary: AppColors.fuchsia, onTertiary: Colors.white,
    surface: surface, onSurface: onSurface,
    error: AppColors.rose, onError: Colors.white,
  );
}
