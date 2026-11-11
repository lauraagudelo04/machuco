import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:machuco/core/design_system/design_system.dart';
import 'package:machuco/models/booking/booking.dart';
import 'package:machuco/routes/routes.dart';
import 'package:machuco/views/booking/owner_view/owner_cash_payment_page.dart';

void main() {
  testWidgets(
    'confirmar el pago en efectivo abre la factura de la reserva pagada',
    (tester) async {
      final pushed = <RouteSettings>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const OwnerCashPaymentPage(
            reservationId: 'owner-reservation-003',
          ),
          onGenerateRoute: (settings) {
            pushed.add(settings);
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => const Scaffold(body: Text('Factura abierta')),
            );
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Confirmar pago en efectivo'));
      await tester.pumpAndSettle();

      expect(find.text('Factura abierta'), findsOneWidget);
      expect(pushed, hasLength(1));
      expect(pushed.single.name, AppRoutes.invoice);
      final reservation = pushed.single.arguments as Reservation;
      expect(reservation.id, 'owner-reservation-003');
      expect(reservation.status, isNot(ReservationStatus.pending));
      expect(
        reservation.invoiceAccessStatus,
        isNot(InvoiceAccessStatus.pending),
      );
    },
  );
}
