import 'package:flutter/material.dart';
import 'app_colors.dart';

abstract final class AppShadows {
  static const cta = [
    BoxShadow(color: Color.fromRGBO(139, 92, 246, .35), offset: Offset(0, 8), blurRadius: 28),
  ];
  static const fab = [
    BoxShadow(color: Color.fromRGBO(139, 92, 246, .40), offset: Offset(0, 8), blurRadius: 28),
  ];
  static const focus = BoxShadow(color: AppColors.violet, blurRadius: 0, spreadRadius: 1);
}
