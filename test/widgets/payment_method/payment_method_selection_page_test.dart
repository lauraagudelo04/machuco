import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:machuco/core/design_system/design_system.dart';
import 'package:machuco/views/payment_method/payment_method_selection_page.dart';

void main() {
  Widget page({ThemeMode themeMode = ThemeMode.light}) => MaterialApp(
    theme: AppTheme.light,
    darkTheme: AppTheme.dark,
    themeMode: themeMode,
    home: const PaymentMethodSelectionPage(
      amount: 156000,
      concept: 'Reserva Loft Neon - Motel 1',
    ),
  );

  for (final themeMode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('muestra En el Local y Tarjeta en tema ${themeMode.name}', (
      tester,
    ) async {
      await tester.pumpWidget(page(themeMode: themeMode));

      expect(find.text('En el Local'), findsOneWidget);
      expect(find.text('Efectivo'), findsNothing);
      expect(find.text('Tarjeta'), findsOneWidget);
      expect(find.text('Paga el valor total en la recepción.'), findsOneWidget);
    });
  }

  testWidgets('En el Local conserva el aviso de pago en recepción', (
    tester,
  ) async {
    await tester.pumpWidget(page());
    await tester.tap(find.text('En el Local'));
    await tester.pumpAndSettle();

    expect(find.text('Pago en recepción'), findsOneWidget);
    expect(find.text('Paga cuando llegues al establecimiento.'), findsOneWidget);
    expect(find.text('Finalizar'), findsOneWidget);
  });

  testWidgets('Tarjeta conserva la navegación al formulario existente', (
    tester,
  ) async {
    await tester.pumpWidget(page());
    await tester.tap(find.text('Tarjeta'));
    await tester.pumpAndSettle();

    expect(find.text('Detalles de la tarjeta'), findsOneWidget);
    expect(find.text('Nombre del titular'), findsOneWidget);
  });
}
