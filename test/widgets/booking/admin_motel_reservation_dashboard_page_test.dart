import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:machuco/core/design_system/design_system.dart';
import 'package:machuco/views/booking/system_admin_view/admin_motel_reservation_dashboard_page.dart';
import 'package:machuco/widgets/booking/simple_bar_line_chart.dart';

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
        _wrap(const AdminMotelReservationDashboardPage(motelId: '1')),
      );

      expect(find.byType(AppSkeleton), findsWidgets);

      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'un motel con histórico muestra el total, el gráfico de evolución y el '
    'desglose de pagos',
    (tester) async {
      await tester.pumpWidget(
        _wrap(const AdminMotelReservationDashboardPage(motelId: '1')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Total histórico de reservas'), findsOneWidget);
      expect(find.text('Sin historial de reservas'), findsNothing);
      expect(find.byType(SimpleBarLineChart), findsOneWidget);

      expect(find.text('Sin pagos registrados'), findsNothing);
      expect(
        find.text('Efectivo').evaluate().isNotEmpty ||
            find.text('Tarjeta').evaluate().isNotEmpty ||
            find.text('Transferencia').evaluate().isNotEmpty,
        isTrue,
        reason: 'Debe listar al menos un método de pago con datos.',
      );
    },
  );

  testWidgets(
    'un motel sin histórico muestra el total en cero (visible, no oculto) '
    'y estados vacíos explicativos en vez de un gráfico vacío',
    (tester) async {
      await tester.pumpWidget(
        _wrap(const AdminMotelReservationDashboardPage(motelId: '3')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Total histórico de reservas'), findsOneWidget);
      expect(find.text('0'), findsOneWidget);

      expect(find.byType(SimpleBarLineChart), findsNothing);
      expect(find.text('Sin historial de reservas'), findsOneWidget);
      expect(find.text('Sin pagos registrados'), findsOneWidget);
    },
  );

  testWidgets(
    'filtrar la evolución por estado no rompe la pantalla de un motel sin '
    'histórico',
    (tester) async {
      await tester.pumpWidget(
        _wrap(const AdminMotelReservationDashboardPage(motelId: '3')),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Estado: Todos'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(PopupMenuItem<String?>, 'Cancelada'),
      );
      await tester.pumpAndSettle();

      expect(find.text('Estado: Cancelada'), findsOneWidget);
      expect(find.text('Sin historial de reservas'), findsOneWidget);
      expect(find.text('0'), findsOneWidget);
    },
  );

  testWidgets(
    'simular error de carga muestra un estado de error con reintento',
    (tester) async {
      await tester.pumpWidget(
        _wrap(const AdminMotelReservationDashboardPage(motelId: '1')),
      );
      await tester.pumpAndSettle();

      await _openDebugMenu(tester);
      await tester.tap(find.text('Simular error de carga'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'No pudimos cargar el dashboard de este motel. Intenta de nuevo.',
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
      _wrap(const AdminMotelReservationDashboardPage(motelId: '1')),
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
