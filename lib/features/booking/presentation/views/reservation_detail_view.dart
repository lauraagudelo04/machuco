import 'package:flutter/material.dart';
import 'package:machuco/core/design_system/design_system.dart';
import 'package:machuco/models/booking/booking.dart';
import 'package:machuco/widgets/booking/booking_widgets.dart';
import 'package:machuco/widgets/layout/responsive_content.dart';
import 'package:machuco/widgets/review/add_review_sheet.dart';
import 'package:machuco/views/booking/booking_view_support.dart';

class BookingDetailPage extends StatefulWidget {
  const BookingDetailPage({
    super.key,
    required this.booking,
    this.now,
    this.onCancel,
    this.onViewInvoice,
    this.onAddReview,
  });

  final Booking booking;
  final DateTime? now;
  final ValueChanged<Booking>? onCancel;
  final ValueChanged<Booking>? onViewInvoice;
  final ValueChanged<Booking>? onAddReview;

  @override
  State<BookingDetailPage> createState() => _BookingDetailPageState();
}

class _BookingDetailPageState extends State<BookingDetailPage> {
  late Booking _booking = widget.booking;

  bool get _statusAllowsCancellation =>
      _booking.status == BookingStatus.confirmed ||
      _booking.status == BookingStatus.pendingPayment;

  bool get _hasFiveFullDaysNotice =>
      _booking.checkIn.difference(widget.now ?? DateTime.now()) >
      const Duration(days: 5);

  bool get _canCancel => _statusAllowsCancellation && _hasFiveFullDaysNotice;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detalle de reserva')),
      body: SafeArea(
        child: SingleChildScrollView(
          child: ResponsiveContent(
            maxWidth: 920,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppCard(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final status = BookingStatusBadge(
                        status: _booking.status,
                      );
                      final title = Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _booking.reference ?? _booking.id,
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: AppSpacing.s1),
                          Text(
                            '${_booking.motelName} · ${_booking.roomName}',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: context.appColors.textSecondary,
                                ),
                          ),
                        ],
                      );
                      if (constraints.maxWidth < 440) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            title,
                            const SizedBox(height: AppSpacing.s3),
                            status,
                          ],
                        );
                      }
                      return Row(
                        children: [
                          Expanded(child: title),
                          const SizedBox(width: AppSpacing.s3),
                          status,
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: AppSpacing.s4),
                ResponsiveSplit(
                  primary: Column(
                    children: [
                      BookingSection(
                        title: 'Estadía',
                        child: Column(
                          children: [
                            _DetailRow(
                              icon: Icons.apartment_outlined,
                              label: 'Motel',
                              value: _booking.motelName,
                            ),
                            _DetailRow(
                              icon: Icons.bedroom_parent_outlined,
                              label: 'Habitación',
                              value:
                                  '${_booking.roomName} · ${_booking.roomNumber}',
                            ),
                            _DetailRow(
                              icon: Icons.people_outline,
                              label: 'Huéspedes',
                              value: '${_booking.guestCount} personas',
                            ),
                            _DetailRow(
                              icon: Icons.login_outlined,
                              label: 'Llegada',
                              value: formatBookingDate(_booking.checkIn),
                            ),
                            _DetailRow(
                              icon: Icons.logout_outlined,
                              label: 'Salida',
                              value: formatBookingDate(_booking.checkOut),
                              isLast: true,
                            ),
                          ],
                        ),
                      ),
                      if (_booking.notes != null) ...[
                        const SizedBox(height: AppSpacing.s4),
                        BookingSection(
                          title: 'Indicaciones',
                          child: Text(_booking.notes!),
                        ),
                      ],
                    ],
                  ),
                  secondary: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      BookingSection(
                        title: 'Pago',
                        child: Column(
                          children: [
                            PriceRow(
                              label: 'Subtotal',
                              value: formatBookingMoney(
                                (_booking.total / 1.19).round(),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.s2),
                            PriceRow(
                              label: 'IVA incluido',
                              value: formatBookingMoney(
                                _booking.total -
                                    (_booking.total / 1.19).round(),
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(
                                vertical: AppSpacing.s3,
                              ),
                              child: Divider(),
                            ),
                            PriceRow(
                              label: 'Total pagado',
                              value: formatBookingMoney(_booking.total),
                              emphasized: true,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.s4),
                      AppButton(
                        label: 'Ver factura',
                        icon: Icons.receipt_long_outlined,
                        variant: AppButtonVariant.secondary,
                        onPressed: _requestInvoice,
                      ),
                      if (_booking.status == BookingStatus.completed) ...[
                        const SizedBox(height: AppSpacing.s3),
                        AppButton(
                          label: 'Añadir reseña',
                          icon: Icons.star_outline,
                          variant: AppButtonVariant.secondary,
                          onPressed: _addReview,
                        ),
                      ],
                      if (_statusAllowsCancellation) ...[
                        const SizedBox(height: AppSpacing.s3),
                        Tooltip(
                          message: _canCancel
                              ? ''
                              : 'Solo se permite cancelar con mínimo 5 días de anticipación',
                          child: AppButton(
                            label: 'Cancelar reserva',
                            icon: Icons.cancel_outlined,
                            variant: AppButtonVariant.destructive,
                            onPressed: _canCancel ? _confirmCancellation : null,
                          ),
                        ),
                        if (!_canCancel) ...[
                          const SizedBox(height: AppSpacing.s2),
                          Text(
                            'Solo se permite cancelar con mínimo 5 días de anticipación',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: context.appColors.textSecondary,
                                ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _requestInvoice() {
    if (widget.onViewInvoice != null) {
      widget.onViewInvoice!(_booking);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('La factura será abierta por el módulo de facturación.'),
      ),
    );
  }

  void _addReview() {
    widget.onAddReview?.call(_booking);
    AddReviewSheet.show(
      context,
      onSave: (_) => ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gracias por compartir tu experiencia.')),
      ),
    );
  }

  Future<void> _confirmCancellation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Cancelar esta reserva?'),
        content: const Text(
          'Revisa la política de devolución aplicable antes de continuar.',
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
    widget.onCancel?.call(_booking);
    setState(
      () => _booking = _booking.copyWith(status: BookingStatus.cancelled),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('La reserva fue cancelada en esta demostración.'),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.isLast = false,
  });
  final IconData icon;
  final String label;
  final String value;
  final bool isLast;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: isLast ? 0 : AppSpacing.s3),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: context.appColors.textSecondary),
        const SizedBox(width: AppSpacing.s3),
        Expanded(child: Text(label)),
        const SizedBox(width: AppSpacing.s3),
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
