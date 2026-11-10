import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:machuco/controllers/booking/client_view/client_booking_controller.dart';
import 'package:machuco/core/design_system/design_system.dart';
import 'package:machuco/models/booking/booking.dart';
import 'package:machuco/repositories/booking/booking_repository.dart';
import 'package:machuco/views/booking/client_view/booking_checkout_page.dart';

final _checkIn = DateTime.now().add(const Duration(days: 2));

final _reservation = Reservation(
  id: 'res-checkout',
  requestId: 'req-checkout',
  guestId: ClientBookingController.demoUserId,
  motelId: '1',
  motelName: 'Motel Prueba',
  roomId: 'room-1-101',
  roomName: 'Suite Prueba',
  roomNumber: '101',
  checkIn: _checkIn,
  checkOut: _checkIn.add(const Duration(hours: 3)),
  stayMode: StayMode.dateTimeRange,
  guestCount: 2,
  services: const [
    ReservationLineItem(
      id: 's1',
      name: 'Jacuzzi extra',
      unitPrice: 20000,
      quantity: 2,
    ),
  ],
  products: const [
    ReservationLineItem(id: 'p1', name: 'Champaña', unitPrice: 30000),
  ],
  roomTotal: 150000,
  total: 220000,
  status: ReservationStatus.upcoming,
  createdAt: DateTime.now(),
);

void main() {
  late BookingRepository original;

  setUp(() => original = BookingRepositoryProvider.instance);
  tearDown(() => BookingRepositoryProvider.instance = original);

  testWidgets('el desglose lista la habitación, cada adicional y el total', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    BookingRepositoryProvider.instance = InMemoryBookingRepository(
      initial: [_reservation],
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: BookingCheckoutPage(reservationId: _reservation.id),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Desglose de costos'), findsOneWidget);
    expect(find.text('Habitación'), findsOneWidget);
    expect(find.text(r'$150.000'), findsOneWidget);
    // Additional items: unit price x quantity.
    expect(find.text('Jacuzzi extra'), findsOneWidget);
    expect(find.text(r'$40.000'), findsOneWidget);
    expect(find.text('Champaña'), findsOneWidget);
    expect(find.text(r'$30.000'), findsOneWidget);
    // Total.
    expect(find.text('Total a pagar'), findsOneWidget);
    expect(find.text(r'$220.000'), findsOneWidget);
  });
}
