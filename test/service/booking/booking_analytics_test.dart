import 'package:flutter_test/flutter_test.dart';
import 'package:machuco/models/booking/booking.dart';
import 'package:machuco/repositories/booking/booking_repository.dart';
import 'package:machuco/service/analytics/analytics_service.dart';
import 'package:machuco/service/booking/booking_service.dart';

import '../analytics/recording_analytics_service.dart';

void main() {
  late RecordingAnalyticsService analytics;
  late BookingService service;

  DateTime at(int day, int hour) => DateTime(2026, 3, day, hour);

  setUp(() {
    analytics = RecordingAnalyticsService();
    service = BookingService(
      repository: InMemoryBookingRepository(),
      now: () => at(10, 12),
      analytics: analytics,
    );
  });

  Future<Reservation> create({String requestId = 'req-1'}) =>
      service.createReservation(
        requestId: requestId,
        motelId: 'm1',
        motelName: 'Motel Uno',
        roomId: 'room-a',
        roomName: 'Suite',
        roomNumber: '1',
        checkIn: at(10, 14),
        checkOut: at(10, 18),
        stayMode: StayMode.dateTimeRange,
        guestCount: 2,
        services: const [],
        products: const [],
        roomTotal: 80000,
        guestName: 'Ana Pérez',
      );

  test('a new reservation reports reservation_created without personal '
      'data', () async {
    await create();

    expect(analytics.events, hasLength(1));
    final event = analytics.events.single;
    expect(event.name, AnalyticsEvents.reservationCreated);
    expect(event.parameters, {
      'motel_id': 'm1',
      'stay_mode': 'dateTimeRange',
      'guest_count': 2,
      'value': 80000,
      'currency': 'COP',
    });
  });

  test('retrying the same request does not report it twice', () async {
    await create();
    await create();

    expect(analytics.eventNames, [AnalyticsEvents.reservationCreated]);
  });

  test('a rejected reservation reports nothing', () async {
    await create();
    await expectLater(create(requestId: 'req-2'), throwsException);

    expect(analytics.eventNames, [AnalyticsEvents.reservationCreated]);
  });

  test('confirming the payment reports reservation_paid', () async {
    final reservation = await create();
    await service.confirmPayment(reservation.id, paymentMethod: 'Tarjeta');

    expect(analytics.events.last.name, AnalyticsEvents.reservationPaid);
    expect(analytics.events.last.parameters, {
      'payment_method': 'Tarjeta',
      'value': 80000,
      'currency': 'COP',
    });
  });

  test('a cash payment of a pending reservation reports it as paid', () async {
    final reservation = await create();
    await service.registerCashPayment(reservation.id);

    expect(analytics.events.last.name, AnalyticsEvents.reservationPaid);
    expect(
      analytics.events.last.parameters['payment_method'],
      BookingService.cashPaymentMethod,
    );
  });

  test('a cash payment of an already paid reservation reports nothing '
      'more', () async {
    final reservation = await create();
    await service.confirmPayment(reservation.id);
    await service.registerCashPayment(reservation.id);

    expect(analytics.eventNames, [
      AnalyticsEvents.reservationCreated,
      AnalyticsEvents.reservationPaid,
    ]);
  });

  test('cancelling reports reservation_cancelled with the previous '
      'status', () async {
    final reservation = await create();
    await service.cancelReservation(reservation.id, 'Cambio de planes');

    expect(analytics.events.last.name, AnalyticsEvents.reservationCancelled);
    expect(analytics.events.last.parameters, {'previous_status': 'pending'});
  });
}
