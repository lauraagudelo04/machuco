import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:machuco/core/design_system/design_system.dart';
import 'package:machuco/views/admin_access/admin_panel_drawer.dart';

Widget _wrap(Widget child) => MaterialApp(theme: AppTheme.light, home: child);

void main() {
  testWidgets('muestra el contador de solicitudes y sus accesos', (
    tester,
  ) async {
    var approvals = 0;
    var profile = 0;
    var logout = 0;

    await tester.pumpWidget(
      _wrap(
        Scaffold(
          endDrawer: AdminPanelDrawer(
            pendingRequests: 3,
            adminEmail: 'admin@machuco.com',
            onOpenApprovals: () => approvals++,
            onOpenProfile: () => profile++,
            onLogout: () => logout++,
          ),
        ),
      ),
    );
    tester.state<ScaffoldState>(find.byType(Scaffold)).openEndDrawer();
    await tester.pumpAndSettle();

    expect(find.text('Sesión: admin@machuco.com'), findsOneWidget);
    expect(find.text('Solicitudes de propietarios'), findsOneWidget);
    expect(find.text('3 pendientes'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);

    await tester.tap(find.text('Solicitudes de propietarios'));
    await tester.tap(find.text('Mi perfil'));
    await tester.tap(find.text('Cerrar sesión'));
    await tester.pumpAndSettle();

    expect(approvals, 1);
    expect(profile, 1);
    expect(logout, 1);
  });

  testWidgets('sin pendientes indica que no hay solicitudes', (tester) async {
    await tester.pumpWidget(
      _wrap(
        Scaffold(
          endDrawer: AdminPanelDrawer(
            pendingRequests: 0,
            adminEmail: null,
            onOpenApprovals: () {},
            onOpenProfile: () {},
            onLogout: () {},
          ),
        ),
      ),
    );
    tester.state<ScaffoldState>(find.byType(Scaffold)).openEndDrawer();
    await tester.pumpAndSettle();

    expect(find.text('Sin solicitudes pendientes'), findsOneWidget);
    expect(find.text('Sesión de administrador'), findsOneWidget);
  });

  testWidgets('el aviso de pendientes llama a revisar', (tester) async {
    var reviewed = 0;
    await tester.pumpWidget(
      _wrap(
        Scaffold(
          body: PendingOwnerRequestsBanner(
            count: 2,
            onReview: () => reviewed++,
          ),
        ),
      ),
    );

    expect(
      find.text('2 solicitudes de propietarios pendientes de aprobación.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Revisar'));
    expect(reviewed, 1);
  });

  testWidgets('el aviso no se muestra sin pendientes', (tester) async {
    await tester.pumpWidget(
      _wrap(
        Scaffold(body: PendingOwnerRequestsBanner(count: 0, onReview: () {})),
      ),
    );

    expect(find.text('Revisar'), findsNothing);
  });
}
