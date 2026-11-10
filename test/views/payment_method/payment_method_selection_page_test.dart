import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:machuco/controllers/payment_method/payment_method_checkout_controller.dart';
import 'package:machuco/core/design_system/design_system.dart';
import 'package:machuco/models/booking/booking.dart';
import 'package:machuco/models/payment/payment.dart';
import 'package:machuco/models/payment_method/payment_method_model.dart';
import 'package:machuco/repositories/booking/booking_repository.dart';
import 'package:machuco/repositories/payment/payment_repository.dart';
import 'package:machuco/routes/routes.dart';
import 'package:machuco/views/payment_method/payment_method_selection_page.dart';

/// Records card payments without touching SQLite or Firebase.
class _FakeCheckout implements PaymentCheckoutController {
  _FakeCheckout({this.failuresBeforeSuccess = 0});

  /// Number of card registrations that fail before one succeeds.
  int failuresBeforeSuccess;
  final registeredCardPayments = <String>[];

  @override
  Future<PaymentCheckoutResult> registerCardPayment(
    Reservation reservation, {
    required CardPaymentKind kind,
  }) async {
    if (failuresBeforeSuccess > 0) {
      failuresBeforeSuccess--;
      throw const PaymentRepositoryException(
        PaymentRepositoryError.connection,
        'No se pudo conectar con el maestro de métodos de pago.',
      );
    }
    registeredCardPayments.add(reservation.id);
    return PaymentCheckoutResult(
      payment: PaymentRecord(
        id: 'pay-${reservation.id}',
        bookingId: reservation.id,
        bookingReference: reservation.requestId,
        clientId: reservation.guestId,
        client: reservation.guestName,
        motelId: reservation.motelId,
        motel: reservation.motelName,
        roomId: reservation.roomId,
        room: reservation.roomName,
        reservationDate: reservation.checkIn,
        amount: reservation.total,
        status: PaymentStatus.paid,
      ),
    );
  }

  @override
  Future<PaymentCheckoutResult> registerPendingLocalPayment(
    Reservation reservation,
  ) => throw UnimplementedError();
}

Future<void> _payWithCard(
  WidgetTester tester,
  Reservation reservation, {
  required PaymentCheckoutController checkoutController,
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
        checkoutController: checkoutController,
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

    final checkout = _FakeCheckout();

    await _payWithCard(tester, pending, checkoutController: checkout);

    expect(checkout.registeredCardPayments, [pending.id]);
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

    final checkout = _FakeCheckout();

    await _payWithCard(tester, notPending, checkoutController: checkout);

    expect(checkout.registeredCardPayments, isEmpty);

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
      checkoutController: _FakeCheckout(),
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

  testWidgets('a failed payment registration can be retried', (tester) async {
    final repository = BookingRepositoryProvider.instance;
    final pending = (await repository.getAll()).firstWhere(
      (r) => r.status == ReservationStatus.pending,
    );
    final checkout = _FakeCheckout(failuresBeforeSuccess: 1);
    var confirmations = 0;

    await _payWithCard(
      tester,
      pending,
      checkoutController: checkout,
      confirmReservationPayment: (id) async {
        confirmations++;
        return confirmations == 1;
      },
    );
    expect(find.text('route:${AppRoutes.invoice}'), findsNothing);

    await tester.tap(find.text('Continuar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    expect(confirmations, 1);
    expect(checkout.registeredCardPayments, [pending.id]);
    expect(find.text('route:${AppRoutes.invoice}'), findsOneWidget);
  });
}

