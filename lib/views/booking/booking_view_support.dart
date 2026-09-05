import 'package:flutter/material.dart';
import 'package:machuco/core/design_system/design_system.dart';
import 'package:machuco/models/booking.dart';

extension BookingStatusPresentation on BookingStatus {
  String get label => switch (this) {
    BookingStatus.pendingPayment => 'Pendiente de pago',
    BookingStatus.confirmed => 'Confirmada',
    BookingStatus.completed => 'Completada',
    BookingStatus.cancelled => 'Cancelada',
  };

  AppStatus get appStatus => switch (this) {
    BookingStatus.pendingPayment => AppStatus.reserved,
    BookingStatus.confirmed => AppStatus.upcoming,
    BookingStatus.completed => AppStatus.completed,
    BookingStatus.cancelled => AppStatus.cancelled,
  };
}

String formatBookingMoney(int value) {
  final digits = value.toString();
  final result = StringBuffer();
  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) result.write('.');
    result.write(digits[index]);
  }
  return '\$${result.toString()} COP';
}

String formatBookingDate(DateTime date) {
  const months = [
    'ene',
    'feb',
    'mar',
    'abr',
    'may',
    'jun',
    'jul',
    'ago',
    'sep',
    'oct',
    'nov',
    'dic',
  ];
  String two(int value) => value.toString().padLeft(2, '0');
  return '${date.day} ${months[date.month - 1]} ${date.year}, '
      '${two(date.hour)}:${two(date.minute)}';
}

class BookingCard extends StatelessWidget {
  const BookingCard({
    super.key,
    required this.booking,
    required this.onTap,
    this.trailing,
  });

  final Booking booking;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      semanticLabel: 'Reserva ${booking.reference}, ${booking.status.label}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: context.appColors.elevated,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(
                  Icons.bedroom_parent_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      booking.roomName,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.s1),
                    Text(
                      '${booking.motelName} · Habitación ${booking.roomNumber}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.appColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              BookingStatusBadge(status: booking.status),
            ],
          ),
          const SizedBox(height: AppSpacing.s3),
          _BookingLine(
            icon: Icons.login_outlined,
            text: formatBookingDate(booking.checkIn),
          ),
          const SizedBox(height: AppSpacing.s2),
          _BookingLine(
            icon: Icons.logout_outlined,
            text: formatBookingDate(booking.checkOut),
          ),
          const SizedBox(height: AppSpacing.s3),
          Row(
            children: [
              Expanded(
                child: Text(
                  formatBookingMoney(booking.total),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              trailing ??
                  const Icon(Icons.chevron_right, semanticLabel: 'Ver detalle'),
            ],
          ),
        ],
      ),
    );
  }
}

class BookingStatusBadge extends StatelessWidget {
  const BookingStatusBadge({super.key, required this.status});

  final BookingStatus status;

  @override
  Widget build(BuildContext context) {
    final appStatus = status.appStatus;
    return Semantics(
      label: 'Estado: ${status.label}',
      child: ExcludeSemantics(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: appStatus.color.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s3,
              vertical: AppSpacing.s1,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(appStatus.icon, size: 16, color: appStatus.color),
                const SizedBox(width: AppSpacing.s1),
                Text(
                  status.label,
                  style: Theme.of(
                    context,
                  ).textTheme.labelMedium?.copyWith(color: appStatus.color),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class BookingEmptyState extends StatelessWidget {
  const BookingEmptyState({
    super.key,
    required this.title,
    required this.description,
    this.action,
  });

  final String title;
  final String description;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s5),
        child: Column(
          children: [
            Icon(
              Icons.event_busy_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: AppSpacing.s3),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.s2),
            Text(
              description,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: context.appColors.textSecondary,
              ),
            ),
            if (action != null) ...[
              const SizedBox(height: AppSpacing.s4),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

class _BookingLine extends StatelessWidget {
  const _BookingLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: context.appColors.textSecondary),
        const SizedBox(width: AppSpacing.s2),
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.bodySmall),
        ),
      ],
    );
  }
}
