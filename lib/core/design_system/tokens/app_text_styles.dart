import 'package:flutter/material.dart';

abstract final class AppTextStyles {
  static const display = TextStyle(fontSize: 30, fontWeight: FontWeight.w800, height: 1.2);
  static const h1 = TextStyle(fontSize: 24, fontWeight: FontWeight.w700, height: 1.3);
  static const h2 = TextStyle(fontSize: 20, fontWeight: FontWeight.w700, height: 1.4);
  static const h3 = TextStyle(fontSize: 18, fontWeight: FontWeight.w600, height: 1.5);
  static const bodyLarge = TextStyle(fontSize: 15, fontWeight: FontWeight.w500, height: 1.6);
  static const body = TextStyle(fontSize: 14, fontWeight: FontWeight.w400, height: 1.5);
  static const bodySmall = TextStyle(fontSize: 13, fontWeight: FontWeight.w400, height: 1.5);
  static const caption = TextStyle(fontSize: 12, fontWeight: FontWeight.w500, height: 1.4);
  static const micro = TextStyle(fontSize: 10, fontWeight: FontWeight.w600, height: 1.4);

  static TextTheme theme(Color color) => TextTheme(
    displayLarge: display.copyWith(color: color),
    headlineLarge: h1.copyWith(color: color),
    headlineMedium: h2.copyWith(color: color),
    headlineSmall: h3.copyWith(color: color),
    bodyLarge: bodyLarge.copyWith(color: color),
    bodyMedium: body.copyWith(color: color),
    bodySmall: bodySmall.copyWith(color: color),
    labelLarge: bodyLarge.copyWith(color: color, fontWeight: FontWeight.w700),
    labelMedium: caption.copyWith(color: color),
    labelSmall: micro.copyWith(color: color),
  );
}
