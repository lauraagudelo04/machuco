import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:machuco/core/design_system/design_system.dart';
import 'package:machuco/models/booking/booking.dart';
import 'package:machuco/routes/routes.dart';
import 'package:machuco/views/booking/client_view/reservation_detail_page.dart';

Widget _wrap(Widget child, {RouteFactory? onGenerateRoute}) => MaterialApp(
  theme: AppTheme.light,
  home: child,
  onGenerateRoute: onGenerateRoute,
);

/// El detalle de reserva es un `ListView` con más contenido que cabe en el
/// tamaño de superficie por defecto de las pruebas de widgets, así que se
/// agranda la vista para que "Cancelar reserva" y "Añadir reseña"
/// (al final de la lista) se monten sin necesidad de hacer scroll manual.
void _useTallViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

AppButton _buttonWithLabel(WidgetTester tester, String label) =>
    tester.widget<AppButton>(
      find.ancestor(of: find.text(label), matching: find.byType(AppButton)),
    );

void main() {
  group('ReservationDetailPage — visibilidad condicional de acciones', () {
    testWidgets(
      'una reserva pending muestra "Completar pago" y "Cancelar reserva", '
      'y oculta "Descargar factura"/"Añadir reseña"',
      (tester) async {
        _useTallViewport(tester);
        await tester.pumpWidget(
          _wrap(
            const ReservationDetailPage(
              reservationId: 'reservation-seed-pending',
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Completar pago'), findsOneWidget);
        expect(find.text('Cancelar reserva'), findsOneWidget);
        expect(find.text('Descargar factura'), findsNothing);
        expect(find.text('Añadir reseña'), findsNothing);
      },
    );

    testWidgets(
      'una reserva active muestra "Descargar factura" habilitado y no '
      'muestra "Completar pago" ni "Cancelar reserva"',
      (tester) async {
        _useTallViewport(tester);
        await tester.pumpWidget(
          _wrap(
            const ReservationDetailPage(
              reservationId: 'reservation-seed-active',
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Completar pago'), findsNothing);
        expect(find.text('Cancelar reserva'), findsNothing);
        expect(
          _buttonWithLabel(tester, 'Descargar factura').onPressed,
          isNotNull,
        );
      },
    );

    testWidgets('una reserva upcoming muestra "Cancelar reserva" y "Descargar '
        'factura" habilitados, y no muestra "Completar pago"', (tester) async {
      _useTallViewport(tester);
      await tester.pumpWidget(
        _wrap(
          const ReservationDetailPage(
            reservationId: 'reservation-seed-upcoming',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Completar pago'), findsNothing);
      expect(find.text('Cancelar reserva'), findsOneWidget);
      expect(
        _buttonWithLabel(tester, 'Descargar factura').onPressed,
        isNotNull,
      );
    });

    testWidgets('una reserva completed muestra "Descargar factura" y la reseña '
        'habilitados, y no muestra "Completar pago" ni "Cancelar reserva"', (
      tester,
    ) async {
      _useTallViewport(tester);
      await tester.pumpWidget(
        _wrap(
          const ReservationDetailPage(
            reservationId: 'reservation-seed-completed',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Completar pago'), findsNothing);
      expect(find.text('Cancelar reserva'), findsNothing);
      expect(
        _buttonWithLabel(tester, 'Descargar factura').onPressed,
        isNotNull,
      );
      expect(_buttonWithLabel(tester, 'Añadir reseña').onPressed, isNotNull);
    });

    testWidgets('una reserva cancelled deja "Descargar factura" oculto '
        '(regresión), habilita la reseña y expone el motivo de cancelación '
        'cuando existe', (tester) async {
      _useTallViewport(tester);
      await tester.pumpWidget(
        _wrap(
          const ReservationDetailPage(
            reservationId: 'reservation-seed-cancelled',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Completar pago'), findsNothing);
      expect(find.text('Cancelar reserva'), findsNothing);
      expect(find.text('Descargar factura'), findsNothing);
      expect(_buttonWithLabel(tester, 'Añadir reseña').onPressed, isNotNull);

      // La reserva de seed cancelada no trae `cancellationReason`, así que
      // la tarjeta de motivo no debería aparecer para ella.
      expect(find.text('Motivo de cancelación'), findsNothing);
    });
  });

  group('ReservationDetailPage — flujo de cancelación', () {
    testWidgets(
      'cancelar sin motivo se bloquea; con motivo cambia el estado, muestra '
      'el badge de cancelada y la tarjeta con el motivo',
      (tester) async {
        _useTallViewport(tester);
        await tester.pumpWidget(
          _wrap(
            const ReservationDetailPage(
              reservationId: 'reservation-seed-upcoming',
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Próxima'), findsOneWidget);
        expect(find.text('Cancelada'), findsNothing);

        await tester.tap(find.text('Cancelar reserva'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Sí, cancelar'));
        await tester.pumpAndSettle();

        // Intentar confirmar sin motivo: queda bloqueado.
        await tester.tap(find.text('Confirmar cancelación'));
        await tester.pumpAndSettle();
        expect(
          find.text('El motivo de cancelación es obligatorio.'),
          findsOneWidget,
        );
        expect(find.text('Próxima'), findsOneWidget);

        await tester.enterText(
          find.byType(TextFormField),
          'Ya no podré asistir a la reserva.',
        );
        await tester.tap(find.text('Confirmar cancelación'));
        await tester.pumpAndSettle();

        expect(find.text('Cancelada'), findsOneWidget);
        expect(find.text('Próxima'), findsNothing);
        expect(find.text('Motivo de cancelación'), findsOneWidget);
        expect(find.text('Ya no podré asistir a la reserva.'), findsOneWidget);
        // Tras cancelar, la acción de cancelar deja de ofrecerse.
        expect(find.text('Cancelar reserva'), findsNothing);
      },
    );
  });

  group('ReservationDetailPage — navegación a completar pago', () {
    testWidgets(
      '"Completar pago" navega a AppRoutes.paymentMethod con la reserva '
      'como argumento',
      (tester) async {
        _useTallViewport(tester);
        String? capturedRouteName;
        Object? capturedArguments;

        await tester.pumpWidget(
          _wrap(
            const ReservationDetailPage(
              reservationId: 'reservation-seed-pending',
            ),
            onGenerateRoute: (settings) {
              capturedRouteName = settings.name;
              capturedArguments = settings.arguments;
              return MaterialPageRoute<void>(
                settings: settings,
                builder: (_) =>
                    const Scaffold(body: Text('Payment Method Stub')),
              );
            },
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Completar pago'));
        await tester.pumpAndSettle();

        expect(capturedRouteName, AppRoutes.paymentMethod);
        expect(capturedArguments, isA<Reservation>());
        expect(
          (capturedArguments as Reservation).id,
          'reservation-seed-pending',
        );
        expect(find.text('Payment Method Stub'), findsOneWidget);
      },
    );
  });
}
