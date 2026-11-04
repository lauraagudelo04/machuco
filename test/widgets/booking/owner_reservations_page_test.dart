import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:machuco/core/design_system/design_system.dart';
import 'package:machuco/views/booking/owner_view/owner_reservations_page.dart';

Widget _wrap(Widget child) => MaterialApp(theme: AppTheme.light, home: child);

/// `OwnerReservationsPage` encadena más de una llamada mockeada con
/// `Future.delayed` (p. ej. `loadReservations` seguido de `_applyFilters`)
/// sin reconstruir el árbol entre ambas. `pumpAndSettle()` deja de pumpear
/// en cuanto deja de haber un frame reprogramado, lo que puede ocurrir
/// justo en el hueco entre esas dos llamadas encadenadas y dejar un Timer
/// pendiente. Por eso primero se avanza el reloj falso lo suficiente para
/// agotar toda la cadena y solo después se llama a `pumpAndSettle()`.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 3));
  await tester.pumpAndSettle();
}

Future<void> _openDebugMenu(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.bug_report_outlined));
  await tester.pumpAndSettle();
}

/// Selecciona una opción de un [PopupMenuButton] de filtro ya abierto.
/// Las tarjetas de reserva detrás del menú pueden repetir el mismo texto
/// (p. ej. el nombre de un motel o una etiqueta de estado), así que hay que
/// acotar la búsqueda al propio `PopupMenuItem` en vez de usar `find.text`.
Future<void> _selectFilterOption(WidgetTester tester, String label) async {
  await tester.tap(find.widgetWithText(PopupMenuItem<String?>, label));
  await _settle(tester);
}

void main() {
  testWidgets(
    'muestra esqueletos de carga antes de resolver la primera consulta',
    (tester) async {
      await tester.pumpWidget(_wrap(const OwnerReservationsPage()));

      expect(find.byType(AppSkeleton), findsWidgets);

      await _settle(tester);
    },
  );

  testWidgets(
    'tras cargar muestra el resumen operativo, los filtros y la lista de '
    'reservas',
    (tester) async {
      await tester.pumpWidget(_wrap(const OwnerReservationsPage()));
      await _settle(tester);

      expect(find.text('Total de reservas'), findsOneWidget);
      expect(find.text('Activas / próximas'), findsOneWidget);
      expect(find.text('Pendientes de pago'), findsOneWidget);
      expect(find.text('Motel: Todos'), findsOneWidget);
      expect(find.text('Estado: Todos'), findsOneWidget);
      expect(find.text('Habitación: Todos'), findsOneWidget);
      expect(find.text('Sin resultados'), findsNothing);
      expect(find.text('Todavía no hay reservas'), findsNothing);
    },
  );

  testWidgets(
    'simular error de carga muestra un estado de error con reintento',
    (tester) async {
      await tester.pumpWidget(_wrap(const OwnerReservationsPage()));
      await _settle(tester);

      await _openDebugMenu(tester);
      await tester.tap(find.text('Simular error de carga'));
      await _settle(tester);

      expect(
        find.text(
          'No pudimos cargar las reservas de tus moteles. Intenta de nuevo.',
        ),
        findsOneWidget,
      );
      expect(find.text('Reintentar'), findsOneWidget);

      await tester.tap(find.text('Reintentar'));
      await _settle(tester);

      expect(find.text('Total de reservas'), findsOneWidget);
    },
  );

  testWidgets('simular sin conexión muestra un estado offline explícito', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const OwnerReservationsPage()));
    await _settle(tester);

    await _openDebugMenu(tester);
    await tester.tap(find.text('Simular sin conexión'));
    await _settle(tester);

    expect(
      find.text('Estás sin conexión. Revisa tu internet e intenta de nuevo.'),
      findsOneWidget,
    );
    expect(find.text('Código: OFFLINE'), findsOneWidget);
  });

  testWidgets(
    'una combinación de filtros sin resultados muestra un estado vacío con '
    'la opción de limpiar filtros',
    (tester) async {
      await tester.pumpWidget(_wrap(const OwnerReservationsPage()));
      await _settle(tester);

      // Motel Paraíso Élite (id '1') no tiene ninguna reserva "completed" en
      // el dataset mockeado de OwnerBookingController.
      await tester.tap(find.text('Motel: Todos'));
      await tester.pumpAndSettle();
      await _selectFilterOption(tester, 'Motel Paraíso Élite');

      await tester.tap(find.text('Estado: Todos'));
      await tester.pumpAndSettle();
      await _selectFilterOption(tester, 'Completada');

      expect(find.text('Sin resultados'), findsOneWidget);
      expect(find.text('Limpiar filtros'), findsOneWidget);

      await tester.tap(find.text('Limpiar filtros'));
      await _settle(tester);

      expect(find.text('Sin resultados'), findsNothing);
      expect(find.text('Motel: Todos'), findsOneWidget);
      expect(find.text('Estado: Todos'), findsOneWidget);
    },
  );

  testWidgets('filtrar por motel recalcula la lista y el resumen operativo', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const OwnerReservationsPage()));
    await _settle(tester);

    await tester.tap(find.text('Motel: Todos'));
    await tester.pumpAndSettle();
    await _selectFilterOption(tester, 'Motel El Edén');

    expect(find.text('Motel: Motel El Edén'), findsOneWidget);
    // Ninguna tarjeta de "Motel Paraíso Élite" debería seguir visible.
    expect(find.text('Motel Paraíso Élite'), findsNothing);
  });
}
