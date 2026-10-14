import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:machuco/core/design_system/design_system.dart';
import 'package:machuco/database/model/suscripcion/subscription.dart';
import 'package:machuco/widgets/subscription/add_payment_sheet.dart';

void main() {
  testWidgets(
    'conserva el formulario si falla y espera el guardado al reintentar',
    (tester) async {
      final saved = Completer<void>();
      var attempts = 0;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return TextButton(
                  child: const Text('Ingresar pago'),
                  onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => AddPaymentSheet(
                      defaultAmount: 150000,
                      loadPaymentMethods: () async => const [
                        SubscriptionPaymentMethod(
                          id: 4,
                          name: 'Transferencia bancaria',
                        ),
                      ],
                      onSave:
                          ({
                            required int amount,
                            required String paymentMethod,
                            required String reference,
                          }) async {
                            attempts++;
                            expect(amount, 150000);
                            expect(paymentMethod, 'Transferencia bancaria');
                            expect(reference, 'TRANS-123');
                            if (attempts == 1) {
                              throw StateError('No se pudo escribir');
                            }
                            await saved.future;
                          },
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.tap(find.text('Ingresar pago'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).last, 'TRANS-123');
      await tester.ensureVisible(find.text('Confirmar pago'));
      await tester.tap(find.text('Confirmar pago'));
      await tester.pumpAndSettle();

      expect(
        find.text('No se pudo guardar el pago. Intenta nuevamente.'),
        findsOneWidget,
      );
      expect(find.text('TRANS-123'), findsOneWidget);
      expect(find.byType(AddPaymentSheet), findsOneWidget);

      await tester.ensureVisible(find.text('Confirmar pago'));
      await tester.tap(find.text('Confirmar pago'));
      await tester.pump();
      expect(attempts, 2);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(AddPaymentSheet), findsOneWidget);

      saved.complete();
      await tester.pumpAndSettle();
      expect(find.byType(AddPaymentSheet), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
