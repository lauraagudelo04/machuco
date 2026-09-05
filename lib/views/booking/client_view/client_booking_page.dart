import 'package:flutter/material.dart';
import 'package:machuco/controllers/booking_controller.dart';
import 'package:machuco/core/design_system/design_system.dart';
import 'package:machuco/models/booking.dart';
import 'package:machuco/routes/routes.dart';
import 'package:machuco/views/booking/booking_view_support.dart';

class ClientBookingPage extends StatefulWidget {
  const ClientBookingPage({super.key});

  @override
  State<ClientBookingPage> createState() => _ClientBookingPageState();
}

class _ClientBookingPageState extends State<ClientBookingPage> {
  late final List<Booking> _bookings = List<Booking>.from(
    BookingController.clientBookings,
  );
  BookingStatus? _filter;

  @override
  Widget build(BuildContext context) {
    final visible = _filter == null
        ? _bookings
        : _bookings.where((item) => item.status == _filter).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Mis reservas')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pushNamed(context, AppRoutes.createBooking),
        icon: const Icon(Icons.add),
        label: const Text('Reservar'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.screen),
          children: [
            Text(
              'Tus próximas visitas',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: AppSpacing.s2),
            Text(
              'Consulta el estado, revisa los detalles o continúa con el pago.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: context.appColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.s4),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ChoiceChip(
                    label: const Text('Todas'),
                    selected: _filter == null,
                    onSelected: (_) => setState(() => _filter = null),
                  ),
                  const SizedBox(width: AppSpacing.s2),
                  ...BookingStatus.values.map(
                    (status) => Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.s2),
                      child: ChoiceChip(
                        label: Text(status.label),
                        selected: _filter == status,
                        onSelected: (_) => setState(() => _filter = status),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.s4),
            if (visible.isEmpty)
              const BookingEmptyState(
                title: 'No hay reservas en este estado',
                description:
                    'Selecciona otro filtro para consultar tu historial.',
              )
            else
              ...visible.map(
                (booking) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.s3),
                  child: BookingCard(
                    booking: booking,
                    onTap: () => Navigator.pushNamed(
                      context,
                      AppRoutes.bookingDetail,
                      arguments: booking,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: AppSpacing.s12),
          ],
        ),
      ),
    );
  }
}
