import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:machuco/core/design_system/design_system.dart';
import 'package:machuco/routes/routes.dart';

void main() {
  testWidgets('retired client payment routes resolve as unknown', (tester) async {
    for (final path in [
      '/payment/client/history',
      '/payment/client/confirmation',
    ]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          onGenerateRoute: AppRoutes.onGenerateRoute,
        ),
      );
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      navigator.pushNamed(path);
      await tester.pumpAndSettle();

      expect(find.text('Ruta no encontrada'), findsOneWidget);
      expect(find.text('Volver al inicio'), findsOneWidget);
    }
  });

  test('owner and admin payment routes remain registered', () {
    for (final path in [AppRoutes.ownerPayments, AppRoutes.adminPayments]) {
      final route = AppRoutes.onGenerateRoute(RouteSettings(name: path));
      expect(route.settings.name, path);
    }
  });
}
