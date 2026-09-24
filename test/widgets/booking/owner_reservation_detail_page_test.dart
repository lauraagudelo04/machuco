import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:machuco/core/design_system/design_system.dart';
import 'package:machuco/views/booking/owner_view/owner_reservation_detail_page.dart';

Widget _wrap(Widget child) => MaterialApp(theme: AppTheme.light, home: child);

void main() {
  group('OwnerReservationDetailPage — visibilidad condicional de acciones', () {
    testWidgets(
      'una reserva pending muestra "Pagar en efectivo" y "Cancelar reserva"',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            const OwnerReservationDetailPage(
              reservationId: 'owner-reservation-003',
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Pagar en efectivo'), findsOneWidget);
        expect(find.text('Cancelar reserva'), findsOneWidget);
      },
    );

    testWidgets(
      'una reserva active no muestra ni "Pagar en efectivo" ni "Cancelar '
      'reserva"',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            const OwnerReservationDetailPage(
              reservationId: 'owner-reservation-001',
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Pagar en efectivo'), findsNothing);
        expect(find.text('Cancelar reserva'), findsNothing);
      },
    );

    testWidgets(
      'una reserva completed no muestra acciones de pago ni cancelación',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            const OwnerReservationDetailPage(
              reservationId: 'owner-reservation-004',
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Pagar en efectivo'), findsNothing);
        expect(find.text('Cancelar reserva'), findsNothing);
      },
    );

    testWidgets(
      'una reserva cancelled no muestra acciones y expone el motivo de '
      'cancelación de forma permanente',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            const OwnerReservationDetailPage(
              reservationId: 'owner-reservation-005',
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Pagar en efectivo'), findsNothing);
        expect(find.text('Cancelar reserva'), findsNothing);
        expect(find.text('Motivo de cancelación'), findsOneWidget);
        expect(
          find.text('El huésped solicitó reprogramar para otra fecha.'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'una reserva no encontrada muestra un estado vacío en vez de un '
      'error inesperado',
      (tester) async {
        await tester.pumpWidget(
          _wrap(const OwnerReservationDetailPage(reservationId: 'no-existe')),
        );
        await tester.pumpAndSettle();

        expect(find.text('Reserva no encontrada'), findsOneWidget);
      },
    );
  });

  group('OwnerReservationDetailPage — flujo de cancelación', () {
    testWidgets('confirmar la cancelación sin motivo la bloquea y no cambia el '
        'estado', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const OwnerReservationDetailPage(
            reservationId: 'owner-reservation-002',
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancelar reserva'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sí, cancelar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirmar cancelación'));
      await tester.pumpAndSettle();

      expect(
        find.text('El motivo de cancelación es obligatorio.'),
        findsOneWidget,
      );
      // El botón de cancelar sigue disponible: el estado no cambió.
      expect(find.text('Cancelar reserva'), findsOneWidget);
    });

    testWidgets(
      'cancelar con motivo cambia el estado, oculta las acciones y avisa '
      'de la notificación simulada',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            const OwnerReservationDetailPage(
              reservationId: 'owner-reservation-006',
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Cancelar reserva'), findsOneWidget);

        await tester.tap(find.text('Cancelar reserva'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Sí, cancelar'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byType(TextFormField),
          'El motel tuvo un imprevisto operativo.',
        );
        await tester.tap(find.text('Confirmar cancelación'));
        await tester.pumpAndSettle();

        expect(
          find.text('Reserva cancelada. Se notificó al cliente.'),
          findsOneWidget,
        );
        expect(find.text('Pagar en efectivo'), findsNothing);
        expect(find.text('Cancelar reserva'), findsNothing);
        expect(find.text('Motivo de cancelación'), findsOneWidget);
        expect(
          find.text('El motel tuvo un imprevisto operativo.'),
          findsOneWidget,
        );
      },
    );
  });
}
