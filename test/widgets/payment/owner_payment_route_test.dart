import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:machuco/routes/routes.dart';
import 'package:machuco/views/payment/owner_view/owner_payment_page.dart';

void main() {
  testWidgets(
    'Booking opens finance for its real motel, not the fallback motel',
    (tester) async {
      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (value) {
              context = value;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      final route =
          AppRoutes.onGenerateRoute(
                const RouteSettings(
                  name: AppRoutes.ownerPayments,
                  arguments: {
                    'motelId': 'real-motel',
                    'motelName': 'Motel real',
                  },
                ),
              )
              as MaterialPageRoute<void>;
      // Inspect the destination without mounting Firebase-dependent controllers.
      final page = route.builder(context) as OwnerPaymentsPage;
      expect(page.motelId, 'real-motel');
      expect(page.motelName, 'Motel real');
    },
  );
}
