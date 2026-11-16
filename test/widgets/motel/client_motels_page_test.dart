import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:machuco/controllers/motel/motel_controller.dart';
import 'package:machuco/core/design_system/design_system.dart';
import 'package:machuco/database/repository/motel/motel_repository.dart';
import 'package:machuco/models/motel/motel_model.dart';
import 'package:machuco/routes/routes.dart';
import 'package:machuco/views/motel/client_view/client_motels_page.dart';

class _CatalogController extends MotelController {
  List<Motel> records = [];
  Object? failure;
  Completer<List<Motel>>? pending;
  int calls = 0;

  @override
  Future<List<Motel>> getRecommendedMotels() async {
    calls++;
    if (pending != null) return pending!.future;
    if (failure != null) throw failure!;
    return records;
  }
}

Motel _motel({
  String id = '11111111-1111-4111-8111-111111111111',
  String name = 'Motel del catálogo real',
  String zone = 'Rionegro',
  bool available = true,
}) => Motel(
  id: id,
  ownerId: 'fixture-owner',
  name: name,
  email: 'fixture@example.com',
  roomCount: 2,
  nit: 'fixture-nit',
  address: 'Dirección de prueba',
  phone: 'fixture-phone',
  generalLocation: zone,
  paymentMethods: const ['Efectivo'],
  imageUrls: const [],
  isAvailable: available,
);

Widget _page(_CatalogController controller, {RouteFactory? routes}) =>
    MaterialApp(
      theme: AppTheme.light,
      home: ClientMotelsPage(controller: controller),
      onGenerateRoute: routes,
    );

void main() {
  testWidgets('shows catalog records, not the in-memory demo list', (
    tester,
  ) async {
    final controller = _CatalogController()..records = [_motel()];
    await tester.pumpWidget(_page(controller));
    await tester.pumpAndSettle();
    expect(find.text('Motel del catálogo real'), findsOneWidget);
    expect(find.text('Motel Paraíso Élite'), findsNothing);
    expect(find.text('Motel El Edén'), findsNothing);
    expect(controller.calls, 1);
  });

  testWidgets('shows loading until the catalog responds', (tester) async {
    final request = Completer<List<Motel>>();
    final controller = _CatalogController()..pending = request;
    await tester.pumpWidget(_page(controller));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    request.complete([_motel()]);
    await tester.pumpAndSettle();
    expect(find.text('Motel del catálogo real'), findsOneWidget);
  });

  testWidgets(
    'refresh discovers a motel created after opening an empty catalog',
    (tester) async {
      final controller = _CatalogController();
      await tester.pumpWidget(_page(controller));
      await tester.pumpAndSettle();
      expect(find.text('Sin moteles disponibles'), findsOneWidget);
      controller.records = [_motel()];
      await tester.tap(find.byTooltip('Actualizar moteles'));
      await tester.pumpAndSettle();
      expect(find.text('Motel del catálogo real'), findsOneWidget);
      expect(controller.calls, 2);
    },
  );

  testWidgets('pull to refresh works even when the catalog is empty', (
    tester,
  ) async {
    final controller = _CatalogController();
    await tester.pumpWidget(_page(controller));
    await tester.pumpAndSettle();
    controller.records = [_motel()];
    await tester.drag(find.byType(ListView), const Offset(0, 350));
    await tester.pumpAndSettle();
    expect(find.text('Motel del catálogo real'), findsOneWidget);
    expect(controller.calls, 2);
  });

  testWidgets('a failed request offers retry without showing fake records', (
    tester,
  ) async {
    final controller = _CatalogController()
      ..failure = const MotelRepositoryException(
        'Sin conexión con SQL Connect',
      );
    await tester.pumpWidget(_page(controller));
    await tester.pumpAndSettle();
    expect(find.text('Sin conexión con SQL Connect'), findsOneWidget);
    expect(find.text('Motel Paraíso Élite'), findsNothing);
    controller.failure = null;
    controller.records = [_motel()];
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(find.text('Motel del catálogo real'), findsOneWidget);
  });

  testWidgets('filters by zone and hides unavailable motels', (tester) async {
    final controller = _CatalogController()
      ..records = [
        _motel(),
        _motel(
          id: '22222222-2222-4222-8222-222222222222',
          name: 'Otro motel',
          zone: 'Medellín',
        ),
        _motel(name: 'Motel inhabilitado', available: false),
      ];
    await tester.pumpWidget(_page(controller));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText), 'rionegro');
    await tester.pumpAndSettle();
    expect(find.text('Motel del catálogo real'), findsOneWidget);
    expect(find.text('Otro motel'), findsNothing);
    expect(find.text('Motel inhabilitado'), findsNothing);
  });

  testWidgets(
    'detail receives the original UUID and returning refreshes the catalog',
    (tester) async {
      final record = _motel();
      final controller = _CatalogController()..records = [record];
      RouteSettings? destination;
      await tester.pumpWidget(
        _page(
          controller,
          routes: (settings) {
            destination = settings;
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => const Scaffold(body: Text('Detalle de prueba')),
            );
          },
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ver más'));
      await tester.pumpAndSettle();
      expect(destination!.name, AppRoutes.clientMotelDetail);
      expect(identical(destination!.arguments, record), isTrue);
      expect((destination!.arguments! as Motel).id, record.id);
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();
      expect(controller.calls, 2);
    },
  );
}
