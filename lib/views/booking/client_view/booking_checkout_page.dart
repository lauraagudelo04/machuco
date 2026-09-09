import 'dart:async';

import 'package:flutter/material.dart';

import 'package:machuco/controllers/booking/client_view/client_booking_controller.dart';
import 'package:machuco/core/design_system/components/app_button.dart';
import 'package:machuco/core/design_system/components/app_card.dart';
import 'package:machuco/core/design_system/components/app_feedback.dart';
import 'package:machuco/core/design_system/components/app_icon_button.dart';
import 'package:machuco/core/design_system/theme/app_theme_extensions.dart';
import 'package:machuco/core/design_system/tokens/app_radius.dart';
import 'package:machuco/core/design_system/tokens/app_spacing.dart';
import 'package:machuco/models/booking/booking.dart';
import 'package:machuco/utils/currency_formatter.dart';
import 'package:machuco/utils/date_formatter.dart';

/// Pantalla completa de resumen previo al pago. Fuera de alcance: el
/// procesamiento real de pagos. El único CTA ("Ir a pagar") deja un stub
/// visual hasta que la selección de método de pago esté disponible.
class BookingCheckoutPage extends StatefulWidget {
  const BookingCheckoutPage({super.key, required this.reservationId});

  final String reservationId;

  @override
  State<BookingCheckoutPage> createState() => _BookingCheckoutPageState();
}

class _BookingCheckoutPageState extends State<BookingCheckoutPage> {
  late final ClientBookingController _controller;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _controller = ClientBookingController();
    // Cuenta regresiva visible del abandono de pago (escenario: si pasan 15
    // minutos en `pending` sin confirmar, la reserva se cancela sola y la
    // franja vuelve a estar disponible).
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      _controller.checkExpirations();
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _goToPayment() {
    // TODO: navegar a la selección real de método de pago cuando esa
    // funcionalidad esté disponible. Queda explícitamente fuera del
    // alcance de "Reserva de habitación" / "Gestión de mis reservas".
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'La selección de método de pago estará disponible próximamente.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final reservation = _controller.getById(widget.reservationId);
    return Scaffold(
      appBar: AppBar(
        leadingWidth: 72,
        leading: Padding(
          padding: const EdgeInsets.only(left: AppSpacing.s3),
          child: AppIconButton(
            icon: Icons.arrow_back_rounded,
            tooltip: 'Volver',
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ),
        title: const Text('Resumen antes de pagar'),
      ),
      body: SafeArea(
        child: reservation == null
            ? AppEmptyState(
                icon: Icons.search_off_outlined,
                title: 'Reserva no encontrada',
                message: 'Es posible que ya haya sido pagada o eliminada.',
                actionLabel: 'Volver',
                onAction: () => Navigator.of(context).maybePop(),
              )
            : reservation.status == ReservationStatus.cancelled
            ? AppErrorState(
                message:
                    'Tu tiempo para pagar esta reserva expiró y la franja volvió a estar disponible. '
                    'Puedes intentar reservar de nuevo.',
                onRetry: () => Navigator.of(context).maybePop(),
              )
            : _CheckoutContent(
                reservation: reservation,
                remaining: _controller.remainingPendingTime(reservation.id),
                onGoToPayment: _goToPayment,
              ),
      ),
    );
  }
}

class _CheckoutContent extends StatelessWidget {
  const _CheckoutContent({
    required this.reservation,
    required this.remaining,
    required this.onGoToPayment,
  });

  final Reservation reservation;
  final Duration? remaining;
  final VoidCallback onGoToPayment;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.screen),
      children: [
        if (remaining != null) ...[
          _CountdownBanner(remaining: remaining!),
          const SizedBox(height: AppSpacing.s4),
        ],
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                reservation.motelName,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: context.appColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.s1),
              Text(
                '${reservation.roomName} · Habitación ${reservation.roomNumber}',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.s4),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Detalle de la reserva',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.s3),
              _DetailRow(
                icon: Icons.event_outlined,
                label: 'Fechas',
                value: formatDateRangeLabel(
                  reservation.checkIn,
                  reservation.checkOut,
                ),
              ),
              const Divider(height: AppSpacing.s5),
              _DetailRow(
                icon: Icons.people_alt_outlined,
                label: 'Personas',
                value: '${reservation.guestCount}',
              ),
              const Divider(height: AppSpacing.s5),
              _DetailRow(
                icon: Icons.tune_outlined,
                label: 'Modalidad',
                value: reservation.stayMode.label,
              ),
            ],
          ),
        ),
        if (reservation.services.isNotEmpty ||
            reservation.products.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.s4),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Servicios y productos',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.s3),
                for (final item in [
                  ...reservation.services,
                  ...reservation.products,
                ])
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.s2),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.name,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                        Text(formatCurrencyAmount(item.subtotal)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.s4),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Total a pagar',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  Text(
                    formatCurrencyAmount(reservation.total),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s5),
              AppButton(
                label: 'Ir a pagar',
                icon: Icons.arrow_forward_rounded,
                onPressed: onGoToPayment,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CountdownBanner extends StatelessWidget {
  const _CountdownBanner({required this.remaining});

  final Duration remaining;

  @override
  Widget build(BuildContext context) {
    final minutes = remaining.inMinutes
        .remainder(60)
        .toString()
        .padLeft(2, '0');
    final seconds = remaining.inSeconds
        .remainder(60)
        .toString()
        .padLeft(2, '0');
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.s3),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          children: [
            Icon(
              Icons.hourglass_top_outlined,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: AppSpacing.s3),
            Expanded(
              child: Text(
                'Confirma el pago antes de $minutes:$seconds o la reserva se cancelará automáticamente.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: context.appColors.textSecondary),
        const SizedBox(width: AppSpacing.s3),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: context.appColors.textSecondary,
            ),
          ),
        ),
        Text(value, style: Theme.of(context).textTheme.titleSmall),
      ],
    );
  }
}
