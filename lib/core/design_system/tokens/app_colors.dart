import 'package:flutter/material.dart';

abstract final class AppColors {
  static const violet = Color(0xFF8B5CF6);
  static const purple = Color(0xFFA855F7);
  static const fuchsia = Color(0xFFD946EF);
  static const fuchsiaText = Color(0xFFF0ABFC);
  static const fuchsiaSoft = Color(0xFFF5D0FE);
  static const rose = Color(0xFFFB7185);
  static const available = Color(0xFF6EE7B7);
  static const reserved = Color(0xFFA78BFA);
  static const occupied = Color(0xFFE879F9);
  static const cleaning = Color(0xFFFDE68A);
  static const maintenance = Color(0xFFFCD34D);
  static const blocked = Color(0xFFFECDD3);
}

abstract final class AppLightColors {
  static const canvas = Color(0xFFF4EFF7);
  static const background = Color(0xFFFAF7FC);
  static const surface = Color(0xFFFFFFFF);
  static const elevated = Color(0xFFF0E8F5);
  static const mediaFallback = Color(0xFFE5D9EC);
  static const textPrimary = Color(0xFF21152C);
  static const textSecondary = Color(0xFF5F5668);
  static const textMuted = Color(0xFF7D7286);
  static const textDisabled = Color.fromRGBO(33, 21, 44, .35);
  static const border = Color.fromRGBO(33, 21, 44, .10);
  static const borderStrong = Color.fromRGBO(33, 21, 44, .18);
}

abstract final class AppDarkColors {
  static const canvas = Color(0xFF0D0913);
  static const background = Color(0xFF100B18);
  static const surface = Color(0xFF15111F);
  static const elevated = Color(0xFF21182B);
  static const mediaFallback = Color(0xFF291B35);
  static const textPrimary = Color(0xFFF8F6FF);
  static const textSecondary = Color.fromRGBO(255, 255, 255, .55);
  static const textMuted = Color.fromRGBO(255, 255, 255, .40);
  static const textDisabled = Color.fromRGBO(255, 255, 255, .25);
  static const border = Color.fromRGBO(255, 255, 255, .07);
  static const borderStrong = Color.fromRGBO(255, 255, 255, .12);
}
