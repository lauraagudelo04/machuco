import 'package:flutter/material.dart';
import 'package:machuco/core/design_system/design_system.dart';

enum ReservationStatus { pending, paid, cancelled, completed, confirmed }

extension ReservationStatusData on ReservationStatus {
  String get label => switch (this) {
    ReservationStatus.pending => 'Pendiente',
    ReservationStatus.confirmed => 'Confirmada',
    ReservationStatus.paid => 'Pagada',
    ReservationStatus.completed => 'Completada',
    ReservationStatus.cancelled => 'Cancelada',
  };
  Color get color => switch (this) {
    ReservationStatus.pending || ReservationStatus.confirmed => AppColors.reserved,
    ReservationStatus.paid || ReservationStatus.completed => AppColors.available,
    ReservationStatus.cancelled => AppColors.blocked,
  };
  IconData get icon => switch (this) {
    ReservationStatus.pending => Icons.pending_outlined,
    ReservationStatus.confirmed => Icons.check_circle_outline,
    ReservationStatus.paid => Icons.payments_outlined,
    ReservationStatus.completed => Icons.event_available_outlined,
    ReservationStatus.cancelled => Icons.cancel_outlined,
  };
  AppStatus get toAppStatus => switch (this) {
  ReservationStatus.pending => AppStatus.reserved,
  ReservationStatus.confirmed => AppStatus.upcoming,
  ReservationStatus.paid => AppStatus.active,
  ReservationStatus.completed => AppStatus.completed,
  ReservationStatus.cancelled => AppStatus.cancelled,
};
}
