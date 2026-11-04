import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:machuco/core/design_system/design_system.dart';
import 'package:machuco/widgets/booking/cancellation_reason_sheet.dart';

/// Pantalla mínima que dispara [showCancellationReasonSheet] y expone el
/// resultado (y si [onConfirm] fue invocado) para poder verificarlo desde
/// las pruebas, igual que lo hacen las páginas reales de Propietario.
class _CancellationHarness extends StatefulWidget {
  const _CancellationHarness();

  @override
  State<_CancellationHarness> createState() => _CancellationHarnessState();
}

class _CancellationHarnessState extends State<_CancellationHarness> {
  bool? lastResult;
  String? confirmedReason;
  int onConfirmCalls = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: AppButton(
          label: 'Cancelar reserva',
          onPressed: () async {
            final result = await showCancellationReasonSheet(
              context,
              onConfirm: (reason) async {
                onConfirmCalls++;
                confirmedReason = reason;
              },
            );
            setState(() => lastResult = result);
          },
        ),
      ),
    );
  }
}

Widget _wrap(Widget child) => MaterialApp(theme: AppTheme.light, home: child);

void main() {
  group('showCancellationReasonSheet / CancellationReasonSheet', () {
    testWidgets('no permite confirmar la cancelación con el motivo vacío', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const _CancellationHarness()));

      await tester.tap(find.text('Cancelar reserva'));
      await tester.pumpAndSettle();

      expect(find.text('¿Cancelar esta reserva?'), findsOneWidget);
      await tester.tap(find.text('Sí, cancelar'));
      await tester.pumpAndSettle();

      expect(find.text('Motivo de cancelación'), findsWidgets);
      await tester.tap(find.text('Confirmar cancelación'));
      await tester.pumpAndSettle();

      expect(
        find.text('El motivo de cancelación es obligatorio.'),
        findsOneWidget,
      );
      // El bottom sheet sigue abierto: el campo de motivo sigue visible.
      expect(find.byType(TextFormField), findsOneWidget);

      final state = tester.state<_CancellationHarnessState>(
        find.byType(_CancellationHarness),
      );
      expect(state.onConfirmCalls, 0);
    });

    testWidgets('confirma solo cuando se ingresa un motivo no vacío', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const _CancellationHarness()));

      await tester.tap(find.text('Cancelar reserva'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sí, cancelar'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextFormField),
        '  El cliente pidió reprogramar  ',
      );
      await tester.tap(find.text('Confirmar cancelación'));
      await tester.pumpAndSettle();

      final state = tester.state<_CancellationHarnessState>(
        find.byType(_CancellationHarness),
      );
      expect(state.onConfirmCalls, 1);
      expect(state.confirmedReason, 'El cliente pidió reprogramar');
      expect(state.lastResult, isTrue);
      // El sheet ya se cerró.
      expect(find.byType(TextFormField), findsNothing);
    });

    testWidgets(
      'volver en el diálogo de confirmación no abre el sheet de motivo',
      (tester) async {
        await tester.pumpWidget(_wrap(const _CancellationHarness()));

        await tester.tap(find.text('Cancelar reserva'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Volver'));
        await tester.pumpAndSettle();

        expect(find.text('Motivo de cancelación'), findsNothing);

        final state = tester.state<_CancellationHarnessState>(
          find.byType(_CancellationHarness),
        );
        expect(state.onConfirmCalls, 0);
        expect(state.lastResult, isFalse);
      },
    );
  });
}
