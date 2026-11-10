import 'package:flutter/material.dart';
import 'package:machuco/models/auth/account_status.dart';
import 'package:machuco/models/auth/user_profile.dart';

/// Texto del estado de un administrador (siempre acompañado de icono).
String administratorStatusLabel(UserProfile profile) {
  if (profile.accountStatus == AccountStatus.disabled) return 'Deshabilitado';
  if (profile.mustChangePassword) return 'Pendiente de cambiar contraseña';
  return 'Activo';
}

IconData administratorStatusIcon(UserProfile profile) {
  if (profile.accountStatus == AccountStatus.disabled) {
    return Icons.block_outlined;
  }
  if (profile.mustChangePassword) return Icons.lock_clock_outlined;
  return Icons.check_circle_outline;
}
