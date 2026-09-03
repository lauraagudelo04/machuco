import 'package:flutter/material.dart';
import 'package:machuco/controllers/booking/client_view/client_booking_controller.dart';
import 'package:machuco/core/design_system/design_system.dart';
import 'package:machuco/models/booking/booking.dart';
import 'package:machuco/routes/routes.dart';
import 'package:machuco/views/booking/booking_view_support.dart';
import 'package:machuco/widgets/booking/booking_widgets.dart';
import 'package:machuco/widgets/layout/responsive_content.dart';

class ClientBookingHomePage extends StatefulWidget {
  const ClientBookingHomePage({super.key, this.bookings});

  final List<Booking>? bookings;

  @override
  State<ClientBookingHomePage> createState() => _ClientBookingHomePageState();
}

class _ClientBookingHomePageState extends State<ClientBookingHomePage> {
  late final List<Booking> _bookings = List<Booking>.unmodifiable(
    widget.bookings ?? ClientBookingController.bookings,
  );
  BookingStatus? _filter;

  @override
  Widget build(BuildContext context) {
    final visible = _filter == null
        ? _bookings
        : _bookings
              .where((booking) => booking.status == _filter)
              .toList(growable: false);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis reservas'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.s3),
            child: AppButton(
              label: 'Nueva reserva',
              icon: Icons.add,
              expanded: false,
              size: AppButtonSize.medium,
              onPressed: () =>
                  Navigator.pushNamed(context, AppRoutes.createBooking),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: ResponsiveContent(
                maxWidth: 920,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Tu historial de estadías',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: AppSpacing.s2),
                    Text(
                      'Revisa próximas visitas, pagos y reservas anteriores.',
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
                          for (final status in BookingStatus.values)
                            Padding(
                              padding: const EdgeInsets.only(
                                right: AppSpacing.s2,
                              ),
                              child: ChoiceChip(
                                label: Text(status.label),
                                selected: _filter == status,
                                onSelected: (_) =>
                                    setState(() => _filter = status),
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
                            'Prueba con otro filtro o crea una nueva reserva.',
                      )
                    else
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final columns = constraints.maxWidth >= 760 ? 2 : 1;
                          const gap = AppSpacing.s3;
                          final width =
                              (constraints.maxWidth - (columns - 1) * gap) /
                              columns;
                          return Wrap(
                            spacing: gap,
                            runSpacing: gap,
                            children: [
                              for (final booking in visible)
                                SizedBox(
                                  width: width,
                                  child: BookingCard(
                                    booking: booking,
                                    onTap: () => Navigator.pushNamed(
                                      context,
                                      AppRoutes.bookingDetail,
                                      arguments: booking,
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BookingNavigationBar(
        selectedIndex: 1,
        onSelected: (index) {
          if (index == 0) {
            Navigator.pushReplacementNamed(context, AppRoutes.clientHome);
          }
          if (index == 2) {
            Navigator.pushReplacementNamed(context, AppRoutes.clientPqrs);
          }
        },
      ),
    );
  }
}
