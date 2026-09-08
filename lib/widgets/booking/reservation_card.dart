import 'package:flutter/material.dart';

import 'package:machuco/core/design_system/components/app_card.dart';
import 'package:machuco/core/design_system/components/status_badge.dart';
import 'package:machuco/core/design_system/theme/app_theme_extensions.dart';
import 'package:machuco/core/design_system/tokens/app_spacing.dart';
import 'package:machuco/models/booking/booking.dart';
import 'package:machuco/utils/currency_formatter.dart';
import 'package:machuco/utils/date_formatter.dart';

/// Traduce el estado de dominio de una reserva al estado visual compartido
/// del sistema de diseño.
AppStatus reservationStatusToAppStatus(ReservationStatus status) =>
    switch (status) {
      ReservationStatus.pending => AppStatus.pending,
      ReservationStatus.active => AppStatus.active,
      ReservationStatus.upcoming => AppStatus.upcoming,
      ReservationStatus.completed => AppStatus.completed,
      ReservationStatus.cancelled => AppStatus.cancelled,
    };

/// Tarjeta de una reserva para listados ("Mis reservas"): motel, número de
/// habitación, precio total, fechas y estado.
class ReservationCard extends StatelessWidget {
  const ReservationCard({super.key, required this.reservation, this.onTap});

  final Reservation reservation;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      semanticLabel:
          'Reserva en ${reservation.motelName}, habitación ${reservation.roomNumber}, '
          'estado ${reservation.status.label}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  reservation.motelName,
                  style: Theme.of(context).textTheme.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.s2),
              StatusBadge(
                status: reservationStatusToAppStatus(reservation.status),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s1),
          Text(
            'Habitación ${reservation.roomNumber} · ${reservation.roomName}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: context.appColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.s2),
          Row(
            children: [
              Icon(
                Icons.event_outlined,
                size: 16,
                color: context.appColors.textSecondary,
              ),
              const SizedBox(width: AppSpacing.s1),
              Expanded(
                child: Text(
                  formatDateRangeLabel(
                    reservation.checkIn,
                    reservation.checkOut,
                  ),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s2),
          Text(
            formatCurrencyAmount(reservation.total),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
