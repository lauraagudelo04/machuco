import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:machuco/controllers/pqrs/pqrs_controller.dart';
import 'package:machuco/core/design_system/design_system.dart';
import 'package:machuco/models/pqrs/pqrs.dart';
import 'package:machuco/core/design_system/theme/app_theme.dart';
import 'package:machuco/views/pqrs/PqrsPage.dart';

PqrsController _storeWith({PqrsStatus status = PqrsStatus.resolved}) {
  return PqrsController.seeded([
    PqrsRequest(
      id: 'r1',
      motelId: 'm1',
      motelName: 'Motel Aurora',
      clientId: 'c-ana',
      clientName: 'Ana Perez',
      type: PqrsType.queja,
      subject: 'Ruido en el pasillo',
      description: 'Hubo ruido excesivo durante la noche.',
      createdAt: DateTime(2026, 8, 1, 10),
      status: status,
      trace: [
        PqrsTraceEntry(
          id: 't1',
          author: PqrsActor.owner,
          message: 'Instalamos burletes.',
          createdAt: DateTime(2026, 8, 2, 10),
          statusChange: status,
        ),
      ],
    ),
  ]);
}

Widget _app(PqrsController store) => MaterialApp(
      theme: AppTheme.light,
      home: PqrsPage(store: store),
    );

void main() {
  // The hub and the profile views are long scrollable pages; a taller surface
  // keeps every section built so the finders do not depend on scroll position.
  setUp(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher.views.first;
    view.physicalSize = const Size(1200, 3000);
    view.devicePixelRatio = 1.0;
    addTearDown(() {
      view.resetPhysicalSize();
      view.resetDevicePixelRatio();
    });
  });

  testWidgets('the hub button opens a modal offering the three PQRS views',
      (tester) async {
    await tester.pumpWidget(_app(_storeWith()));

    await tester.tap(find.text('Ir a una vista de PQRS'));
    await tester.pumpAndSettle();

    expect(find.text('¿A qué vista de PQRS quieres ir?'), findsOneWidget);
    expect(find.text('Cliente'), findsOneWidget);
    expect(find.text('Propietario'), findsOneWidget);
    expect(find.text('Administrador del sistema'), findsOneWidget);
  });

  testWidgets('choosing a profile navigates to that profile view',
      (tester) async {
    await tester.pumpWidget(_app(_storeWith()));

    await tester.tap(find.text('Ir a una vista de PQRS'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Propietario'));
    await tester.pumpAndSettle();

    expect(find.text('PQRS de mi motel'), findsOneWidget);
  });

  testWidgets('the administrator view exposes no composer', (tester) async {
    await tester.pumpWidget(_app(_storeWith()));

    await tester.tap(find.text('Ir a una vista de PQRS'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Administrador del sistema'));
    await tester.pumpAndSettle();

    expect(find.text('PQRS por motel'), findsOneWidget);
    expect(find.text('Registrar avance'), findsNothing);
    expect(find.text('Responder al propietario'), findsNothing);
  });

  testWidgets('only the client sees the closing action, and only once resolved',
      (tester) async {
    final store = _storeWith(status: PqrsStatus.inProgress);
    await tester.pumpWidget(_app(store));

    await tester.tap(find.text('Ir a una vista de PQRS'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cliente'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ruido en el pasillo'));
    await tester.pumpAndSettle();
    expect(find.text('Confirmar solución y cerrar'), findsNothing);

    store.markResolved(requestId: 'r1', message: 'Listo.');
    await tester.pumpAndSettle();
    expect(find.text('Confirmar solución y cerrar'), findsOneWidget);
  });
}
