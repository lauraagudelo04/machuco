import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:machuco/core/design_system/design_system.dart';
import 'package:machuco/models/booking/booking.dart';
import 'package:machuco/repositories/booking/booking_repository.dart';
import 'package:machuco/routes/routes.dart';
import 'package:machuco/views/payment_method/payment_method_selection_page.dart';

Future<void> _payWithCard(
  WidgetTester tester,
  Reservation reservation, {
  Future<bool> Function(String reservationId)? confirmReservationPayment,
}) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: PaymentMethodSelectionPage(
        reservation: reservation,
        confirmReservationPayment: confirmReservationPayment,
      ),
      onGenerateRoute: (settings) => MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => Scaffold(body: Text('route:${settings.name}')),
      ),
    ),
  );

  await tester.tap(find.text('Tarjeta'));
  await tester.pumpAndSettle();

  final fields = find.byType(TextField);
  await tester.enterText(fields.at(0), 'Usuario Demo');
  await tester.enterText(fields.at(1), '4242424242424242');
  await tester.enterText(fields.at(2), '12/99');
  await tester.enterText(fields.at(3), '123');
  await tester.pump();

  await tester.tap(find.textContaining('Pagar'));
  await tester.pump();
  // Simulated gateway delay.
  await tester.pump(const Duration(seconds: 2));
  await tester.pump();

  await tester.tap(find.text('Continuar'));
  await tester.pump();
  // Booking confirmation delay.
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  late BookingRepository originalRepository;

  setUp(() {
    originalRepository = BookingRepositoryProvider.instance;
    BookingRepositoryProvider.instance = InMemoryBookingRepository();
  });

  tearDown(() {
    BookingRepositoryProvider.instance = originalRepository;
  });

  testWidgets('card payment success confirms the pending reservation', (
    tester,
  ) async {
    final repository = BookingRepositoryProvider.instance;
    final pending = (await repository.getAll()).firstWhere(
      (r) => r.status == ReservationStatus.pending,
    );

    await _payWithCard(tester, pending);

    final stored = await repository.getById(pending.id);
    expect(stored?.status, isNot(ReservationStatus.pending));
    expect(stored?.paymentMethod, isNotNull);
    expect(find.text('route:${AppRoutes.invoice}'), findsOneWidget);
  });

  testWidgets('shows a snackbar when the reservation is no longer pending', (
    tester,
  ) async {
    final repository = BookingRepositoryProvider.instance;
    final notPending = (await repository.getAll()).firstWhere(
      (r) => r.status == ReservationStatus.completed,
    );

    await _payWithCard(tester, notPending);

    expect(find.textContaining('No pudimos confirmar el pago'), findsOneWidget);
    expect(find.text('route:${AppRoutes.invoice}'), findsNothing);
    expect(
      (await repository.getById(notPending.id))?.status,
      ReservationStatus.completed,
    );
  });

  testWidgets('uses the injected payment confirmation', (tester) async {
    final repository = BookingRepositoryProvider.instance;
    final pending = (await repository.getAll()).firstWhere(
      (r) => r.status == ReservationStatus.pending,
    );
    String? confirmedId;

    await _payWithCard(
      tester,
      pending,
      confirmReservationPayment: (id) async {
        confirmedId = id;
        return true;
      },
    );

    expect(confirmedId, pending.id);
    expect(find.text('route:${AppRoutes.invoice}'), findsOneWidget);
    expect(
      (await repository.getById(pending.id))?.status,
      ReservationStatus.pending,
    );
  });
}
