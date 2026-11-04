import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:machuco/core/design_system/design_system.dart';
import 'package:machuco/views/booking/system_admin_view/admin_motel_reservations_list_page.dart';

Widget _wrap(Widget child) => MaterialApp(theme: AppTheme.light, home: child);

Future<void> _openDebugMenu(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.bug_report_outlined));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'muestra esqueletos de carga antes de resolver la primera consulta',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          const AdminMotelReservationsListPage(ownerId: 'owner-1020304050'),
        ),
      );

      expect(find.byType(AppSkeleton), findsWidgets);

      await tester.pumpAndSettle();
    },
  );

  testWidgets('lista los moteles de un propietario con su KPI básico', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(const AdminMotelReservationsListPage(ownerId: 'owner-1020304050')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Motel Paraíso Élite'), findsOneWidget);
    expect(find.text('Motel El Edén'), findsOneWidget);
    expect(find.text('Total reservas'), findsWidgets);
    expect(find.text('Promedio mensual de reservas: 0.0'), findsNothing);
  });

  testWidgets(
    'un propietario sin moteles muestra un estado vacío explicativo',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          const AdminMotelReservationsListPage(ownerId: 'owner-sin-moteles'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sin moteles registrados'), findsOneWidget);
    },
  );

  testWidgets(
    'un motel sin histórico de reservas no rompe el listado y muestra sus '
    'KPIs en cero',
    (tester) async {
      await tester.pumpWidget(
        _wrap(const AdminMotelReservationsListPage(ownerId: 'owner-900123456')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Motel Eclipse'), findsOneWidget);
      expect(find.text('Promedio mensual de reservas: 0.0'), findsOneWidget);
      // Con un único motel no hay comparación posible: no debe destacar
      // ningún desempeño.
      expect(find.text('Mejor desempeño'), findsNothing);
      expect(find.text('Necesita atención'), findsNothing);
    },
  );

  testWidgets(
    'simular error de carga muestra un estado de error con reintento',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          const AdminMotelReservationsListPage(ownerId: 'owner-1020304050'),
        ),
      );
      await tester.pumpAndSettle();

      await _openDebugMenu(tester);
      await tester.tap(find.text('Simular error de carga'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'No pudimos cargar los moteles de este propietario. Intenta de '
          'nuevo.',
        ),
        findsOneWidget,
      );
      expect(find.text('Reintentar'), findsOneWidget);
    },
  );

  testWidgets('simular sin conexión muestra un estado offline explícito', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(const AdminMotelReservationsListPage(ownerId: 'owner-1020304050')),
    );
    await tester.pumpAndSettle();

    await _openDebugMenu(tester);
    await tester.tap(find.text('Simular sin conexión'));
    await tester.pumpAndSettle();

    expect(
      find.text('Estás sin conexión. Revisa tu internet e intenta de nuevo.'),
      findsOneWidget,
    );
  });
}
