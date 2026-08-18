import 'package:flutter/material.dart';
import 'app_colors.dart';

abstract final class AppGradients {
  static const primary = LinearGradient(
    colors: [AppColors.violet, AppColors.purple, AppColors.fuchsia],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );
  static const mediaOverlay = LinearGradient(
    colors: [Colors.transparent, Color.fromRGBO(16, 11, 24, .92)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}
