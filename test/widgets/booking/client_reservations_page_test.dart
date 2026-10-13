import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:machuco/core/design_system/design_system.dart';
import 'package:machuco/models/booking/booking.dart';
import 'package:machuco/repositories/booking/booking_repository.dart';
import 'package:machuco/routes/routes.dart';
import 'package:machuco/views/booking/client_view/client_reservations_page.dart';

Widget _wrap() => MaterialApp(
  theme: AppTheme.light,
  home: const ClientReservationsPage(),
  onGenerateRoute: (settings) {
    if (settings.name == AppRoutes.clientMotels) {
      return MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => const Scaffold(body: Text('Pantalla de moteles')),
      );
    }
    return null;
  },
);

Future<void> _settle(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 2));
  await tester.pumpAndSettle();
}

class _FailingRepository implements BookingRepository {
  @override
  Future<List<Reservation>> getAll() => Future.error(StateError('offline'));

  @override
  Future<Reservation?> getById(String id) => Future.error(StateError('x'));

  @override
  Future<Reservation?> findByRequestId(String id) =>
      Future.error(StateError('x'));

  @override
  Future<void> add(Reservation reservation) => Future.error(StateError('x'));

  @override
  Future<void> update(Reservation reservation) => Future.error(StateError('x'));
}

void main() {
  late BookingRepository original;

  setUp(() => original = BookingRepositoryProvider.instance);
  tearDown(() => BookingRepositoryProvider.instance = original);

  testWidgets('un cliente sin reservas ve un estado vacío con la acción de '
      'explorar moteles', (tester) async {
    BookingRepositoryProvider.instance = InMemoryBookingRepository(
      initial: const [],
    );
    await tester.pumpWidget(_wrap());
    await _settle(tester);

    expect(find.text('Todavía no tienes reservas'), findsOneWidget);
    expect(find.text('Explorar moteles'), findsOneWidget);

    await tester.tap(find.text('Explorar moteles'));
    await tester.pumpAndSettle();

    expect(find.text('Pantalla de moteles'), findsOneWidget);
  });

  testWidgets('si la consulta falla muestra un error con reintento y no un '
      'listado vacío', (tester) async {
    BookingRepositoryProvider.instance = _FailingRepository();
    await tester.pumpWidget(_wrap());
    await _settle(tester);

    expect(find.text('Algo salió mal'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
    expect(find.text('Todavía no tienes reservas'), findsNothing);
    expect(find.text('Explorar moteles'), findsNothing);

    // Retrying while the repository still fails keeps the error state.
    await tester.tap(find.text('Reintentar'));
    await _settle(tester);

    expect(find.text('Algo salió mal'), findsOneWidget);
    expect(find.text('Todavía no tienes reservas'), findsNothing);
  });

  testWidgets('con reservas muestra filtros por motel y habitación y el '
      'orden configurable', (tester) async {
    BookingRepositoryProvider.instance = InMemoryBookingRepository();
    await tester.pumpWidget(_wrap());
    await _settle(tester);

    expect(find.text('Motel'), findsWidgets);
    expect(find.text('Habitación'), findsWidgets);
    expect(find.text('Ordenar por'), findsWidgets);
    expect(find.byTooltip('Orden descendente'), findsOneWidget);

    await tester.tap(find.byTooltip('Orden descendente'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Orden ascendente'), findsOneWidget);
    expect(find.text('Todavía no tienes reservas'), findsNothing);
  });
}
