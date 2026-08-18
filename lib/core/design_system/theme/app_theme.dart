import 'package:flutter/material.dart';
import '../tokens/app_colors.dart';
import '../tokens/app_radius.dart';
import '../tokens/app_spacing.dart';
import '../tokens/app_text_styles.dart';
import 'app_color_scheme.dart';
import 'app_theme_extensions.dart';

abstract final class AppTheme {
  static ThemeData get light => _build(brightness: Brightness.light, scheme: AppColorScheme.light, background: AppLightColors.background, canvas: AppLightColors.canvas, elevated: AppLightColors.elevated, mediaFallback: AppLightColors.mediaFallback, secondary: AppLightColors.textSecondary, muted: AppLightColors.textMuted, disabled: AppLightColors.textDisabled, border: AppLightColors.border, borderStrong: AppLightColors.borderStrong);
  static ThemeData get dark => _build(brightness: Brightness.dark, scheme: AppColorScheme.dark, background: AppDarkColors.background, canvas: AppDarkColors.canvas, elevated: AppDarkColors.elevated, mediaFallback: AppDarkColors.mediaFallback, secondary: AppDarkColors.textSecondary, muted: AppDarkColors.textMuted, disabled: AppDarkColors.textDisabled, border: AppDarkColors.border, borderStrong: AppDarkColors.borderStrong);

  static ThemeData _build({required Brightness brightness, required ColorScheme scheme, required Color background, required Color canvas, required Color elevated, required Color mediaFallback, required Color secondary, required Color muted, required Color disabled, required Color border, required Color borderStrong}) {
    OutlineInputBorder inputBorder(Color color) => OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: color));
    final textTheme = AppTextStyles.theme(scheme.onSurface);
    return ThemeData(
      useMaterial3: true, brightness: brightness, colorScheme: scheme,
      scaffoldBackgroundColor: background, canvasColor: canvas, fontFamily: 'Inter', textTheme: textTheme,
      visualDensity: VisualDensity.standard,
      extensions: [AppSemanticColors(canvas: canvas, elevated: elevated, mediaFallback: mediaFallback, textSecondary: secondary, textMuted: muted, textDisabled: disabled, border: border, borderStrong: borderStrong)],
      appBarTheme: AppBarTheme(backgroundColor: background, foregroundColor: scheme.onSurface, elevation: 0, centerTitle: false, titleTextStyle: AppTextStyles.h2.copyWith(color: scheme.onSurface)),
      cardTheme: CardThemeData(color: scheme.surface, elevation: 0, margin: EdgeInsets.zero, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg), side: BorderSide(color: border))),
      inputDecorationTheme: InputDecorationTheme(filled: true, fillColor: elevated, contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12), hintStyle: AppTextStyles.body.copyWith(color: muted), labelStyle: AppTextStyles.body.copyWith(color: secondary), border: inputBorder(Colors.transparent), enabledBorder: inputBorder(Colors.transparent), focusedBorder: inputBorder(AppColors.violet), errorBorder: inputBorder(AppColors.rose), focusedErrorBorder: inputBorder(AppColors.rose)),
      chipTheme: ChipThemeData(backgroundColor: elevated, selectedColor: AppColors.violet.withValues(alpha: .16), side: BorderSide(color: border), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.pill)), labelStyle: AppTextStyles.caption.copyWith(color: scheme.onSurface)),
      navigationBarTheme: NavigationBarThemeData(backgroundColor: canvas, elevation: 0, height: 72, indicatorColor: AppColors.violet.withValues(alpha: .18), labelTextStyle: WidgetStatePropertyAll(AppTextStyles.caption.copyWith(color: scheme.onSurface))),
      dialogTheme: DialogThemeData(backgroundColor: elevated, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xxl))),
      bottomSheetTheme: BottomSheetThemeData(backgroundColor: elevated, modalBackgroundColor: elevated, showDragHandle: true, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xxl)))),
      snackBarTheme: SnackBarThemeData(backgroundColor: elevated, contentTextStyle: AppTextStyles.body.copyWith(color: scheme.onSurface), behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md))),
      filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(minimumSize: const Size(48, 52), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)), textStyle: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w700))),
      outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(minimumSize: const Size(48, 52), side: BorderSide(color: borderStrong), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)))),
      iconButtonTheme: const IconButtonThemeData(style: ButtonStyle(minimumSize: WidgetStatePropertyAll(Size.square(AppSpacing.s12)))),
      dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.violet),
    );
  }
}
