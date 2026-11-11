import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:machuco/core/design_system/design_system.dart';
import 'package:machuco/models/client/client_model.dart';
import 'package:machuco/views/booking/owner_view/owner_reservations_page.dart';
import 'package:machuco/views/client/owner_view/client_detail_page.dart';

const _historyLabel = 'Ver historial de reservas';

Widget _wrap(ClientModel client) => MaterialApp(
  theme: AppTheme.light,
  home: ClientDetailPage(client: client),
);

void main() {
  testWidgets('abre el historial de reservas acotado a ese cliente', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const ClientModel(
          uid: 'client-001',
          name: 'Ana Gómez',
          phone: '3001234567',
          email: 'ana@machuco.com',
          countryCode: '+57',
        ),
      ),
    );

    await tester.ensureVisible(find.text(_historyLabel));
    await tester.pumpAndSettle();
    await tester.tap(find.text(_historyLabel));
    await tester.pumpAndSettle();
    // Let the history finish its simulated load before disposing.
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    final page = tester.widget<OwnerReservationsPage>(
      find.byType(OwnerReservationsPage),
    );
    expect(page.clientId, 'client-001');
    expect(page.clientName, 'Ana Gómez');
    expect(find.text('Reservas de Ana Gómez'), findsOneWidget);
  });

  testWidgets('sin uid no ofrece el historial', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const ClientModel(
          name: 'Sin cuenta',
          phone: '3000000000',
          email: 'sin@machuco.com',
          countryCode: '+57',
        ),
      ),
    );

    expect(find.text(_historyLabel), findsNothing);
  });
}
