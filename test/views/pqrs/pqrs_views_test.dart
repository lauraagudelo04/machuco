import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:machuco/controllers/pqrs/pqrs_controller.dart';
import 'package:machuco/controllers/pqrs/pqrs_photo_controller.dart';
import 'package:machuco/controllers/pqrs/pqrs_type_catalog.dart';
import 'package:machuco/core/design_system/design_system.dart';
import 'package:machuco/database/repository/pqrs/pqrs_repository.dart';
import 'package:machuco/models/pqrs/pqrs.dart';
import 'package:machuco/models/pqrs/pqrs_session.dart';
import 'package:machuco/models/pqrs/pqrs_settings.dart';
import 'package:machuco/service/media/pqrs_photo_picker.dart';
import 'package:machuco/views/pqrs/client_view/pqrs_detail_page.dart';
import 'package:machuco/views/pqrs/client_view/pqrs_page.dart';
import 'package:machuco/views/pqrs/owner_view/pqrs_detail_page.dart';
import 'package:machuco/views/pqrs/owner_view/pqrs_page.dart';

import '../../fakes/in_memory_pqrs_repository.dart';

class _NoPicker implements PqrsPhotoPicker {
  @override
  Future<PqrsPickedPhoto?> pick({
    required PqrsPhotoOrigin origin,
    required PqrsSettings settings,
  }) async => null;
}

final _now = DateTime(2026, 11, 17, 10);

PqrsRequest _request({
  String id = 'p1',
  PqrsStatus status = PqrsStatus.pending,
  DateTime? resolvedAt,
  PqrsClosedBy? closedBy,
}) => PqrsRequest(
  id: id,
  motelId: 'm1',
  motelName: 'Motel Luna',
  clientId: 'client-1',
  clientName: 'Ana Pérez',
  ownerId: 'owner-1',
  type: PqrsType.queja,
  subject: 'Demora en el check-in',
  description: 'Esperé mucho tiempo en la recepción.',
  createdAt: DateTime(2026, 11, 1, 9),
  status: status,
  resolvedAt: resolvedAt,
  closedBy: closedBy,
);

PqrsController _controller(InMemoryPqrsRepository repository, PqrsActor role) =>
    PqrsController(
      repository: repository,
      session: PqrsSession(
        uid: role == PqrsActor.client ? 'client-1' : 'owner-1',
        role: role,
        name: role == PqrsActor.client ? 'Ana Pérez' : 'Dueño Luna',
      ),
      clock: () => _now,
    );

Future<void> _show(WidgetTester tester, Widget page) async {
  tester.view.physicalSize = const Size(800, 3200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: page));
  await tester.pumpAndSettle();
}

Widget _clientDetail(PqrsController controller, {String id = 'p1'}) =>
    ClientPqrsDetailPage(
      requestId: id,
      controller: controller,
      catalog: PqrsTypeCatalog(),
      photos: PqrsPhotoController(
        picker: _NoPicker(),
        author: PqrsActor.client,
      ),
    );

Widget _ownerDetail(PqrsController controller) => OwnerPqrsDetailPage(
  requestId: 'p1',
  controller: controller,
  photos: PqrsPhotoController(picker: _NoPicker(), author: PqrsActor.owner),
);

void main() {
  group('Client', () {
    testWidgets('empty list offers a new request', (tester) async {
      final controller = _controller(
        InMemoryPqrsRepository(),
        PqrsActor.client,
      );
      await _show(tester, ClientPqrsPage(controller: controller));

      expect(find.text('Aún no tienes solicitudes'), findsOneWidget);
      expect(find.text('Nueva solicitud'), findsOneWidget);
    });

    testWidgets('in progress: comment box and no close button', (tester) async {
      final repository = InMemoryPqrsRepository(
        seed: [_request(status: PqrsStatus.inProgress)],
      );
      await _show(
        tester,
        _clientDetail(_controller(repository, PqrsActor.client)),
      );

      expect(find.text('Enviar comentario'), findsOneWidget);
      expect(find.text('Confirmar solución y cerrar'), findsNothing);
    });

    testWidgets('resolved: deadline notice and close button', (tester) async {
      final repository = InMemoryPqrsRepository(
        seed: [
          _request(
            status: PqrsStatus.resolved,
            resolvedAt: DateTime(2026, 11, 16, 10),
          ),
        ],
      );
      await _show(
        tester,
        _clientDetail(_controller(repository, PqrsActor.client)),
      );

      expect(find.text('Confirmar solución y cerrar'), findsOneWidget);
      expect(
        find.text(
          'Si no confirmas antes del 23/11/2026, el propietario podrá '
          'cerrarla',
        ),
        findsOneWidget,
      );
    });

    testWidgets('closed: final notice without box or buttons', (tester) async {
      final repository = InMemoryPqrsRepository(
        seed: [
          _request(status: PqrsStatus.closed, closedBy: PqrsClosedBy.client),
        ],
      );
      await _show(
        tester,
        _clientDetail(_controller(repository, PqrsActor.client)),
      );

      expect(find.text('Esta solicitud está cerrada'), findsOneWidget);
      expect(find.text('Enviar comentario'), findsNothing);
      expect(find.text('Confirmar solución y cerrar'), findsNothing);
    });

    testWidgets('unknown request shows not found', (tester) async {
      final controller = _controller(
        InMemoryPqrsRepository(),
        PqrsActor.client,
      );
      await _show(tester, _clientDetail(controller, id: 'nope'));

      expect(find.text('Solicitud no encontrada'), findsOneWidget);
    });

    testWidgets('a failed send keeps the comment text', (tester) async {
      final repository = InMemoryPqrsRepository(
        seed: [_request(status: PqrsStatus.inProgress)],
      );
      await _show(
        tester,
        _clientDetail(_controller(repository, PqrsActor.client)),
      );

      await tester.enterText(find.byType(TextField).first, 'Sigo esperando');
      repository.failNext = const PqrsFailure(
        PqrsFailureKind.connection,
        'Sin conexión',
      );
      await tester.tap(find.text('Enviar comentario'));
      await tester.pumpAndSettle();

      expect(find.text('Sigo esperando'), findsOneWidget);
      expect(find.text('Sin conexión'), findsOneWidget);
    });

    testWidgets('failed action shows reason, retry and discard', (
      tester,
    ) async {
      final repository = InMemoryPqrsRepository(
        seed: [_request(status: PqrsStatus.inProgress)],
      )..syncStates['p1'] = const PqrsSyncState.failed('El plazo cambió');
      await _show(
        tester,
        _clientDetail(_controller(repository, PqrsActor.client)),
      );

      expect(find.text('No se pudo enviar'), findsOneWidget);
      expect(find.text('El plazo cambió'), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);
      expect(find.text('Descartar'), findsOneWidget);
    });
  });

  group('Owner', () {
    testWidgets('empty inbox shows empty state and zero rates', (tester) async {
      final controller = _controller(InMemoryPqrsRepository(), PqrsActor.owner);
      await _show(tester, OwnerPqrsPage(controller: controller));

      expect(find.text('Sin solicitudes'), findsOneWidget);
      expect(find.text('Mi desempeño'), findsOneWidget);
      expect(find.text('0%'), findsWidgets);
    });

    testWidgets('filter without results shows the empty message', (
      tester,
    ) async {
      final repository = InMemoryPqrsRepository(seed: [_request()]);
      await _show(
        tester,
        OwnerPqrsPage(controller: _controller(repository, PqrsActor.owner)),
      );

      expect(find.text('Demora en el check-in'), findsOneWidget);
      expect(find.textContaining('Ana Pérez'), findsWidgets);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Cerrada'));
      await tester.pumpAndSettle();

      expect(find.text('No hay solicitudes con este estado'), findsOneWidget);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Todas'));
      await tester.pumpAndSettle();
      expect(find.text('Demora en el check-in'), findsOneWidget);
    });

    testWidgets('overdue resolved request is flagged in the inbox', (
      tester,
    ) async {
      final repository = InMemoryPqrsRepository(
        seed: [
          _request(
            status: PqrsStatus.resolved,
            resolvedAt: _now.subtract(const Duration(days: 8)),
          ),
        ],
      );
      await _show(
        tester,
        OwnerPqrsPage(controller: _controller(repository, PqrsActor.owner)),
      );

      expect(find.text('Plazo vencido'), findsOneWidget);
    });

    testWidgets('pending: answer, solve and reject are offered', (
      tester,
    ) async {
      final repository = InMemoryPqrsRepository(seed: [_request()]);
      await _show(
        tester,
        _ownerDetail(_controller(repository, PqrsActor.owner)),
      );

      expect(find.text('Enviar avance'), findsOneWidget);
      expect(find.text('Marcar como solucionada'), findsOneWidget);
      expect(find.text('Rechazar solicitud'), findsOneWidget);
      expect(find.text('Cerrar por falta de respuesta'), findsNothing);
    });

    testWidgets('resolved before the deadline: no box and no timeout close', (
      tester,
    ) async {
      final repository = InMemoryPqrsRepository(
        seed: [
          _request(
            status: PqrsStatus.resolved,
            resolvedAt: _now.subtract(const Duration(days: 3)),
          ),
        ],
      );
      await _show(
        tester,
        _ownerDetail(_controller(repository, PqrsActor.owner)),
      );

      expect(find.text('Enviar avance'), findsNothing);
      expect(find.text('Rechazar solicitud'), findsNothing);
      expect(find.text('Cerrar por falta de respuesta'), findsNothing);
    });

    testWidgets('resolved after the deadline: timeout close is offered', (
      tester,
    ) async {
      final repository = InMemoryPqrsRepository(
        seed: [
          _request(
            status: PqrsStatus.resolved,
            resolvedAt: _now.subtract(const Duration(days: 8)),
          ),
        ],
      );
      await _show(
        tester,
        _ownerDetail(_controller(repository, PqrsActor.owner)),
      );

      expect(find.text('Cerrar por falta de respuesta'), findsOneWidget);
      expect(find.text('Enviar avance'), findsNothing);
    });

    testWidgets('rejected: final notice only', (tester) async {
      final repository = InMemoryPqrsRepository(
        seed: [_request(status: PqrsStatus.rejected)],
      );
      await _show(
        tester,
        _ownerDetail(_controller(repository, PqrsActor.owner)),
      );

      expect(find.text('Esta solicitud está rechazada'), findsOneWidget);
      expect(find.text('Rechazar solicitud'), findsNothing);
    });

    testWidgets('reject dialog requires at least 10 characters', (
      tester,
    ) async {
      final repository = InMemoryPqrsRepository(seed: [_request()]);
      await _show(
        tester,
        _ownerDetail(_controller(repository, PqrsActor.owner)),
      );

      await tester.tap(find.text('Rechazar solicitud'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'corto');
      await tester.tap(find.widgetWithText(TextButton, 'Rechazar'));
      await tester.pumpAndSettle();

      expect(find.textContaining('al menos 10 caracteres'), findsOneWidget);
      expect(repository.appendTraceCalls, 0);
    });
  });
}
