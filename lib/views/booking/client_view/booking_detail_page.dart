import 'package:flutter/material.dart';
import 'package:machuco/core/design_system/design_system.dart';
import 'package:machuco/models/booking.dart';
import 'package:machuco/routes/routes.dart';
import 'package:machuco/views/booking/booking_view_support.dart';

class BookingDetailPage extends StatefulWidget {
  const BookingDetailPage({super.key, required this.booking});
  final Booking booking;

  @override
  State<BookingDetailPage> createState() => _BookingDetailPageState();
}

class _BookingDetailPageState extends State<BookingDetailPage> {
  late Booking _booking = widget.booking;

  @override
  Widget build(BuildContext context) {
    final canCancel =
        _booking.status == BookingStatus.confirmed ||
        _booking.status == BookingStatus.pendingPayment;
    return Scaffold(
      appBar: AppBar(title: const Text('Detalle de reserva')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.screen),
          children: [
            AppCard(
              child: Column(
                children: [
                  Icon(
                    Icons.verified_outlined,
                    size: 52,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: AppSpacing.s3),
                  Text(
                    _booking.reference ?? _booking.id,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: AppSpacing.s2),
                  BookingStatusBadge(status: _booking.status),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.s4),
            _DetailSection(
              title: 'Habitación',
              children: [
                _DetailRow(
                  icon: Icons.apartment_outlined,
                  label: 'Motel',
                  value: _booking.motelName,
                ),
                _DetailRow(
                  icon: Icons.bedroom_parent_outlined,
                  label: 'Habitación',
                  value: '${_booking.roomName} · ${_booking.roomNumber}',
                ),
                _DetailRow(
                  icon: Icons.people_outline,
                  label: 'Huéspedes',
                  value: '${_booking.guestCount} personas',
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s3),
            _DetailSection(
              title: 'Horario',
              children: [
                _DetailRow(
                  icon: Icons.login_outlined,
                  label: 'Llegada',
                  value: formatBookingDate(_booking.checkIn),
                ),
                _DetailRow(
                  icon: Icons.logout_outlined,
                  label: 'Salida',
                  value: formatBookingDate(_booking.checkOut),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s3),
            _DetailSection(
              title: 'Pago',
              children: [
                _DetailRow(
                  icon: Icons.payments_outlined,
                  label: 'Total',
                  value: formatBookingMoney(_booking.total),
                ),
                _DetailRow(
                  icon: Icons.receipt_long_outlined,
                  label: 'Estado',
                  value: _booking.paymentStatus.name,
                ),
              ],
            ),
            if (_booking.notes != null) ...[
              const SizedBox(height: AppSpacing.s3),
              _DetailSection(
                title: 'Indicaciones',
                children: [Text(_booking.notes!)],
              ),
            ],
            const SizedBox(height: AppSpacing.s5),
            if (_booking.paymentStatus == BookingPaymentStatus.pending)
              AppButton(
                label: 'Ir al pago',
                icon: Icons.credit_card_outlined,
                onPressed: () =>
                    Navigator.pushNamed(context, AppRoutes.payment),
              ),
            if (_booking.paymentStatus == BookingPaymentStatus.pending)
              const SizedBox(height: AppSpacing.s3),
            if (canCancel)
              AppButton(
                label: 'Cancelar reserva',
                icon: Icons.cancel_outlined,
                variant: AppButtonVariant.destructive,
                onPressed: _confirmCancellation,
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmCancellation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Cancelar esta reserva?'),
        content: const Text(
          'Esta interacción solo demuestra el estado visual de cancelación.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Volver'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancelar reserva'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(
      () => _booking = _booking.copyWith(status: BookingStatus.cancelled),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Reserva marcada como cancelada en esta demostración.'),
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({required this.title, required this.children});
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.s3),
        ...children,
      ],
    ),
  );
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
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.s3),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: context.appColors.textSecondary),
        const SizedBox(width: AppSpacing.s3),
        Expanded(child: Text(label)),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ),
      ],
    ),
  );
}
