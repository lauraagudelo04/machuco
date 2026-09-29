import 'dart:async';

import 'package:flutter/material.dart';

import 'package:machuco/controllers/booking/owner_view/owner_booking_controller.dart';
import 'package:machuco/core/design_system/design_system.dart';
import 'package:machuco/models/booking/booking.dart';
import 'package:machuco/utils/currency_formatter.dart';
import 'package:machuco/widgets/layout/responsive_content.dart';

/// Pantalla de cobro en efectivo: muestra el concepto y el monto a cobrar
/// de una reserva, con un único botón de confirmación que registra el pago.
/// La generación de la factura queda fuera de alcance: tras confirmar, el
/// acceso a "Ver factura" solo queda marcado como pendiente.
class OwnerCashPaymentPage extends StatefulWidget {
  const OwnerCashPaymentPage({super.key, required this.reservationId});

  final String reservationId;

  @override
  State<OwnerCashPaymentPage> createState() => _OwnerCashPaymentPageState();
}

class _OwnerCashPaymentPageState extends State<OwnerCashPaymentPage> {
  late final OwnerBookingController _controller;
  bool _isLoading = true;
  bool _isSubmitting = false;
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

  Future<void> _confirmPayment() async {
    setState(() => _isSubmitting = true);
    try {
      await _controller.registerCashPayment(widget.reservationId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Cobro registrado. El acceso a la factura queda pendiente.',
          ),
        ),
      );
      Navigator.of(context).pop(true);
    } on ReservationCancellationException catch (error) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
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
        title: const Text('Cobro en efectivo'),
      ),
      body: SafeArea(child: _buildBody(context)),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoading) {
      return ResponsiveContent(
        child: ListView(children: const [AppSkeleton(height: 180)]),
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

    return ResponsiveContent(
      child: ListView(
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Concepto',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: context.appColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.s1),
                Text(
                  'Reserva ${reservation.roomName} · '
                  '${reservation.motelName}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.s1),
                Text(
                  'Huésped: ${reservation.guestName.isEmpty ? 'Sin registrar' : reservation.guestName}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: context.appColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.s4),
                Text(
                  'Monto a cobrar',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: context.appColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.s1),
                Text(
                  formatCurrencyAmount(reservation.total),
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.s5),
          AppButton(
            label: 'Confirmar pago en efectivo',
            icon: Icons.payments_outlined,
            loading: _isSubmitting,
            onPressed: _isSubmitting ? null : _confirmPayment,
          ),
        ],
      ),
    );
  }
}
