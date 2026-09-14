import 'dart:async';

import 'package:flutter/material.dart';

import 'package:machuco/controllers/booking/owner_view/owner_booking_controller.dart';
import 'package:machuco/core/design_system/design_system.dart';
import 'package:machuco/models/booking/booking.dart';
import 'package:machuco/routes/routes.dart';
import 'package:machuco/utils/currency_formatter.dart';
import 'package:machuco/utils/date_formatter.dart';
import 'package:machuco/widgets/booking/cancellation_reason_sheet.dart';
import 'package:machuco/widgets/booking/reservation_card.dart';
import 'package:machuco/widgets/booking/reservation_info_row.dart';
import 'package:machuco/widgets/layout/responsive_content.dart';

/// Detalle de una reserva para Propietario: referencia, huésped, personas,
/// habitación, fechas y estado (sin timeline). Acciones "Pagar en
/// efectivo" y "Cancelar" visibles solo cuando el estado de la reserva lo
/// permite.
class OwnerReservationDetailPage extends StatefulWidget {
  const OwnerReservationDetailPage({super.key, required this.reservationId});

  final String reservationId;

  @override
  State<OwnerReservationDetailPage> createState() =>
      _OwnerReservationDetailPageState();
}

class _OwnerReservationDetailPageState
    extends State<OwnerReservationDetailPage> {
  late final OwnerBookingController _controller;
  bool _isLoading = true;
  Reservation? _reservation;

  @override
  void initState() {
    super.initState();
    _controller = OwnerBookingController();
    unawaited(_load());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final reservation = await _controller.getById(widget.reservationId);
    if (!mounted) return;
    setState(() {
      _reservation = reservation;
      _isLoading = false;
    });
  }

  Future<void> _goToCashPayment() async {
    await Navigator.pushNamed(
      context,
      AppRoutes.ownerCashPayment,
      arguments: widget.reservationId,
    );
    unawaited(_load());
  }

  Future<void> _cancel() async {
    final cancelled = await showCancellationReasonSheet(
      context,
      onConfirm: (reason) async {
        try {
          await _controller.cancelReservation(widget.reservationId, reason);
        } on ReservationCancellationException catch (error) {
          if (!mounted) return;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(error.message)));
        }
      },
    );
    if (cancelled) {
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reserva cancelada. Se notificó al cliente.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
      body: SafeArea(child: _buildBody(context)),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoading) {
      return ResponsiveContent(
        child: ListView(
          children: const [
            AppSkeleton(height: 32, width: 140),
            SizedBox(height: AppSpacing.s4),
            AppSkeleton(height: 220),
          ],
        ),
      );
    }

    final reservation = _reservation;
    if (reservation == null) {
      return AppEmptyState(
        icon: Icons.search_off_outlined,
        title: 'Reserva no encontrada',
        message: 'No encontramos esta reserva en tus moteles.',
        actionLabel: 'Volver',
        onAction: () => Navigator.of(context).maybePop(),
      );
    }

    final canPay = reservation.status == ReservationStatus.pending;
    final canCancel =
        reservation.status == ReservationStatus.pending ||
        reservation.status == ReservationStatus.upcoming;

    return ResponsiveContent(
      child: ListView(
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
                ReservationInfoRow(
                  icon: Icons.tag_outlined,
                  label: 'Referencia',
                  value: reservation.id,
                ),
                const Divider(height: AppSpacing.s5),
                ReservationInfoRow(
                  icon: Icons.person_outline,
                  label: 'Huésped',
                  value: reservation.guestName.isEmpty
                      ? 'Sin registrar'
                      : reservation.guestName,
                ),
                const Divider(height: AppSpacing.s5),
                ReservationInfoRow(
                  icon: Icons.people_alt_outlined,
                  label: 'Personas',
                  value: '${reservation.guestCount}',
                ),
                const Divider(height: AppSpacing.s5),
                ReservationInfoRow(
                  icon: Icons.event_outlined,
                  label: 'Fechas',
                  value: formatDateRangeLabel(
                    reservation.checkIn,
                    reservation.checkOut,
                  ),
                ),
                const Divider(height: AppSpacing.s5),
                ReservationInfoRow(
                  icon: Icons.payments_outlined,
                  label: 'Total',
                  value: formatCurrencyAmount(reservation.total),
                ),
                if (reservation.invoiceAccessStatus ==
                    InvoiceAccessStatus.pending) ...[
                  const Divider(height: AppSpacing.s5),
                  const ReservationInfoRow(
                    icon: Icons.receipt_long_outlined,
                    label: 'Factura',
                    value: 'Pendiente por generar',
                  ),
                ],
              ],
            ),
          ),
          if (reservation.status == ReservationStatus.cancelled &&
              reservation.cancellationReason != null) ...[
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
          if (canPay || canCancel) const SizedBox(height: AppSpacing.s5),
          if (canPay)
            AppButton(
              label: 'Pagar en efectivo',
              icon: Icons.payments_outlined,
              onPressed: _goToCashPayment,
            ),
          if (canPay && canCancel) const SizedBox(height: AppSpacing.s3),
          if (canCancel)
            AppButton(
              label: 'Cancelar reserva',
              icon: Icons.block_outlined,
              variant: AppButtonVariant.destructive,
              onPressed: _cancel,
            ),
        ],
      ),
    );
  }
}
