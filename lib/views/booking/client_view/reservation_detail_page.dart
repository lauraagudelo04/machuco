import 'package:flutter/material.dart';

import 'package:machuco/controllers/booking/client_view/client_booking_controller.dart';
import 'package:machuco/core/design_system/components/app_button.dart';
import 'package:machuco/core/design_system/components/app_card.dart';
import 'package:machuco/core/design_system/components/app_feedback.dart';
import 'package:machuco/core/design_system/components/app_icon_button.dart';
import 'package:machuco/core/design_system/components/status_badge.dart';
import 'package:machuco/core/design_system/theme/app_theme_extensions.dart';
import 'package:machuco/core/design_system/tokens/app_spacing.dart';
import 'package:machuco/models/booking/booking.dart';
import 'package:machuco/routes/routes.dart';
import 'package:machuco/utils/currency_formatter.dart';
import 'package:machuco/utils/date_formatter.dart';
import 'package:machuco/widgets/booking/cancellation_reason_sheet.dart';
import 'package:machuco/widgets/booking/reservation_card.dart';
import 'package:machuco/routes/routes.dart';

/// Detalle completo de una reserva del cliente: estado arriba, información
/// en formato de lista (sin timeline) y dos acciones al final.
class ReservationDetailPage extends StatefulWidget {
  const ReservationDetailPage({super.key, required this.reservationId});

  final String reservationId;

  @override
  State<ReservationDetailPage> createState() => _ReservationDetailPageState();
}

class _ReservationDetailPageState extends State<ReservationDetailPage> {
  late final ClientBookingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ClientBookingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _showStub(String action) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$action disponible como acción visual.')),
    );
  }

  void _goToPaymentMethod(Reservation reservation) {
    Navigator.of(
      context,
    ).pushNamed(AppRoutes.paymentMethod, arguments: reservation);
  }

  Future<void> _cancelReservation(Reservation reservation) async {
    final cancelled = await showCancellationReasonSheet(
      context,
      onConfirm: (reason) async {
        try {
          await _controller.cancelReservation(reservation.id, reason);
        } on ReservationCancellationException catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(e.message)));
          }
        }
      },
    );
    if (cancelled && mounted) setState(() {});
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
        title: const Text('Detalle de la reserva'),
      ),
      body: SafeArea(
        child: reservation == null
            ? AppEmptyState(
                icon: Icons.search_off_outlined,
                title: 'Reserva no encontrada',
                message: 'No encontramos esta reserva en tu historial.',
                actionLabel: 'Volver',
                onAction: () => Navigator.of(context).maybePop(),
              )
            : ListView(
                padding: const EdgeInsets.all(AppSpacing.screen),
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: StatusBadge(
                      status: reservationStatusToAppStatus(reservation.status),
                      size: StatusBadgeSize.small,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s3),
                  Text(
                    reservation.motelName,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: context.appColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s1),
                  Text(
                    '${reservation.roomName} · Habitación ${reservation.roomNumber}',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: AppSpacing.s4),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Información general',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: AppSpacing.s3),
                        _InfoRow(
                          icon: Icons.event_outlined,
                          label: 'Fechas',
                          value: formatDateRangeLabel(
                            reservation.checkIn,
                            reservation.checkOut,
                          ),
                        ),
                        const Divider(height: AppSpacing.s5),
                        _InfoRow(
                          icon: Icons.people_alt_outlined,
                          label: 'Personas',
                          value: '${reservation.guestCount}',
                        ),
                        const Divider(height: AppSpacing.s5),
                        _InfoRow(
                          icon: Icons.tune_outlined,
                          label: 'Modalidad',
                          value: reservation.stayMode.label,
                        ),
                        const Divider(height: AppSpacing.s5),
                        _InfoRow(
                          icon: Icons.payments_outlined,
                          label: 'Total pagado/estimado',
                          value: formatCurrencyAmount(reservation.total),
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
                              padding: const EdgeInsets.only(
                                bottom: AppSpacing.s2,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      item.name,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodyMedium,
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
                  if (reservation.cancellationReason != null) ...[
                    const SizedBox(height: AppSpacing.s4),
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Motivo de cancelación',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: AppSpacing.s2),
                          Text(
                            reservation.cancellationReason!,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.s5),
                  if (_completePaymentEnabled(reservation.status)) ...[
                    AppButton(
                      label: 'Completar pago',
                      icon: Icons.payments_outlined,
                      onPressed: () => _goToPaymentMethod(reservation),
                    ),
                    const SizedBox(height: AppSpacing.s3),
                  ],
                  AppButton(
                    label: 'Descargar factura',
                    icon: Icons.receipt_long_outlined,
                    variant: AppButtonVariant.secondary,
                    onPressed: _invoiceEnabled(reservation.status)
                        ? () => Navigator.pushNamed(
                              context,
                              AppRoutes.invoice,
                              arguments: reservation,
                            )
                        : null,
                  ),
                  const SizedBox(height: AppSpacing.s3),
                  AppButton(
                    label: 'Ver / Añadir reseña',
                    icon: Icons.rate_review_outlined,
                    variant: AppButtonVariant.secondary,
                    // TODO: conectar con la feature de reseñas
                    // (lib/views/review/add_review_page.dart) cuando esa
                    // rama exponga una ruta e integración con reservas.
                    onPressed: _reviewEnabled(reservation.status)
                        ? () => _showStub('Ver / Añadir reseña')
                        : null,
                  ),
                  if (_cancelEnabled(reservation.status)) ...[
                    const SizedBox(height: AppSpacing.s3),
                    AppButton(
                      label: 'Cancelar reserva',
                      icon: Icons.block_outlined,
                      variant: AppButtonVariant.destructive,
                      onPressed: () => _cancelReservation(reservation),
                    ),
                  ],
                ],
              ),
      ),
    );
  }

  bool _completePaymentEnabled(ReservationStatus status) =>
      status == ReservationStatus.pending;

  bool _invoiceEnabled(ReservationStatus status) => switch (status) {
    ReservationStatus.active ||
    ReservationStatus.upcoming ||
    ReservationStatus.completed => true,
    ReservationStatus.pending || ReservationStatus.cancelled => false,
  };

  bool _reviewEnabled(ReservationStatus status) => switch (status) {
    ReservationStatus.completed || ReservationStatus.cancelled => true,
    ReservationStatus.pending ||
    ReservationStatus.active ||
    ReservationStatus.upcoming => false,
  };

  bool _cancelEnabled(ReservationStatus status) =>
      status == ReservationStatus.pending ||
      status == ReservationStatus.upcoming;
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
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
