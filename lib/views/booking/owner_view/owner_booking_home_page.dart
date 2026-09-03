import 'package:flutter/material.dart';
import 'package:machuco/controllers/booking/owner_view/owner_booking_controller.dart';
import 'package:machuco/core/design_system/design_system.dart';
import 'package:machuco/models/booking/booking.dart';
import 'package:machuco/views/booking/booking_view_support.dart';

class OwnerBookingHomePage extends StatefulWidget {
  const OwnerBookingHomePage({super.key});

  @override
  State<OwnerBookingHomePage> createState() => _OwnerBookingHomePageState();
}

class _OwnerBookingHomePageState extends State<OwnerBookingHomePage> {
  late final List<Booking> _bookings = List<Booking>.from(
    OwnerBookingController.bookings,
  );
  String? _selectedMotelId;

  @override
  Widget build(BuildContext context) {
    final motelIds = _bookings.map((item) => item.motelId).toSet().toList();
    final visible = _selectedMotelId == null
        ? _bookings
        : _bookings.where((item) => item.motelId == _selectedMotelId).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Reservas de mis hoteles')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.screen),
          children: [
            _OwnerOverview(bookings: visible),
            const SizedBox(height: AppSpacing.s4),
            Text(
              'Filtrar por hotel',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.s2),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ChoiceChip(
                    label: const Text('Todos'),
                    selected: _selectedMotelId == null,
                    onSelected: (_) => setState(() => _selectedMotelId = null),
                  ),
                  const SizedBox(width: AppSpacing.s2),
                  ...motelIds.map((id) {
                    final name = _bookings
                        .firstWhere((item) => item.motelId == id)
                        .motelName;
                    return Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.s2),
                      child: ChoiceChip(
                        label: Text(name),
                        selected: _selectedMotelId == id,
                        onSelected: (_) =>
                            setState(() => _selectedMotelId = id),
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.s5),
            ...visible.map(
              (booking) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.s3),
                child: BookingCard(
                  booking: booking,
                  onTap: () => _showOwnerDetail(booking),
                  trailing:
                      booking.status == BookingStatus.confirmed ||
                          booking.status == BookingStatus.pendingPayment
                      ? TextButton.icon(
                          onPressed: () => _cancelAndNotify(booking),
                          icon: const Icon(Icons.notifications_active_outlined),
                          label: const Text('Cancelar'),
                        )
                      : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _cancelAndNotify(Booking booking) async {
    final reason = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Cancelar y notificar',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: AppSpacing.s2),
              Text(
                'El cliente recibirá una notificación discreta con el cambio de estado.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: context.appColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.s4),
              const AppTextField(
                label: 'Motivo',
                hint: 'Ej. Habitación fuera de servicio',
                maxLines: 3,
              ),
              const SizedBox(height: AppSpacing.s4),
              AppButton(
                label: 'Confirmar cancelación',
                icon: Icons.send_outlined,
                variant: AppButtonVariant.destructive,
                onPressed: () => Navigator.pop(context, true),
              ),
            ],
          ),
        ),
      ),
    );
    if (reason != true || !mounted) return;
    final index = _bookings.indexWhere((item) => item.id == booking.id);
    setState(
      () =>
          _bookings[index] = booking.copyWith(status: BookingStatus.cancelled),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Cancelación visual registrada. Notificación simulada enviada.',
        ),
      ),
    );
  }

  void _showOwnerDetail(Booking booking) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                booking.reference ?? booking.id,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: AppSpacing.s3),
              Text('${booking.guestName} · ${booking.guestCount} huéspedes'),
              const SizedBox(height: AppSpacing.s2),
              Text('${booking.roomName} · Habitación ${booking.roomNumber}'),
              const SizedBox(height: AppSpacing.s2),
              Text(formatBookingDate(booking.checkIn)),
              const SizedBox(height: AppSpacing.s3),
              BookingStatusBadge(status: booking.status),
            ],
          ),
        ),
      ),
    );
  }
}

class _OwnerOverview extends StatelessWidget {
  const _OwnerOverview({required this.bookings});
  final List<Booking> bookings;

  @override
  Widget build(BuildContext context) {
    final active = bookings
        .where((item) => item.status == BookingStatus.confirmed)
        .length;
    final pending = bookings
        .where((item) => item.status == BookingStatus.pendingPayment)
        .length;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Resumen operativo',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: AppSpacing.s4),
          Row(
            children: [
              Expanded(
                child: _OwnerMetric(
                  label: 'Reservas',
                  value: '${bookings.length}',
                ),
              ),
              const SizedBox(width: AppSpacing.s3),
              Expanded(
                child: _OwnerMetric(label: 'Confirmadas', value: '$active'),
              ),
              const SizedBox(width: AppSpacing.s3),
              Expanded(
                child: _OwnerMetric(label: 'Por pagar', value: '$pending'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OwnerMetric extends StatelessWidget {
  const _OwnerMetric({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(value, style: Theme.of(context).textTheme.headlineSmall),
      Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: context.appColors.textSecondary),
      ),
    ],
  );
}
