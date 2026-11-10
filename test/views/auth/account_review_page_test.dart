import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:machuco/views/account_review/account_review_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_test_support.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pumpPage(WidgetTester tester, AccountReviewArgs args) async {
    tester.view.physicalSize = const Size(412, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      testApp(
        AccountReviewPage(
          args: args,
          controller: buildTestController(FakeAuthService()),
        ),
      ),
    );
  }

  testWidgets('variante pendiente: mensaje, correo y accesos', (tester) async {
    await pumpPage(tester, const AccountReviewArgs(email: 'dueno@example.com'));

    expect(find.text('Cuenta en revisión'), findsOneWidget);
    expect(find.text('Tu cuenta está en revisión'), findsOneWidget);
    expect(find.text('dueno@example.com'), findsOneWidget);
    expect(find.byIcon(Icons.hourglass_top_outlined), findsOneWidget);
    expect(find.text('Cerrar sesión'), findsOneWidget);
    expect(find.text('Eliminar cuenta'), findsOneWidget);
    expect(find.text('Motivo'), findsNothing);
  });

  testWidgets('variante rechazada: muestra el motivo', (tester) async {
    await pumpPage(
      tester,
      const AccountReviewArgs(
        email: 'dueno@example.com',
        rejected: true,
        rejectionReason: 'El NIT no coincide con el RUT.',
      ),
    );

    expect(find.text('Solicitud rechazada'), findsOneWidget);
    expect(find.text('Tu solicitud fue rechazada'), findsOneWidget);
    expect(find.text('Motivo'), findsOneWidget);
    expect(find.text('El NIT no coincide con el RUT.'), findsOneWidget);
    expect(find.byIcon(Icons.cancel_outlined), findsOneWidget);
    expect(find.text('Cerrar sesión'), findsOneWidget);
    expect(find.text('Eliminar cuenta'), findsNothing);
  });
}
