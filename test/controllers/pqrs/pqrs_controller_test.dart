import 'package:flutter_test/flutter_test.dart';
import 'package:machuco/controllers/pqrs/pqrs_controller.dart';
import 'package:machuco/database/repository/pqrs/pqrs_repository.dart';
import 'package:machuco/models/pqrs/pqrs.dart';
import 'package:machuco/models/pqrs/pqrs_session.dart';

import '../../fakes/in_memory_pqrs_repository.dart';

void main() {
  const clientSession = PqrsSession(
    uid: 'client-1',
    role: PqrsActor.client,
    name: 'Ana',
  );
  const ownerSession = PqrsSession(
    uid: 'owner-1',
    role: PqrsActor.owner,
    name: 'Omar',
  );
  const adminSession = PqrsSession(
    uid: 'admin-1',
    role: PqrsActor.systemAdmin,
    name: 'Admin',
  );

  final now = DateTime(2026, 11, 20, 10);
  final resolvedAt = DateTime(2026, 11, 10, 10);

  PqrsRequest request(
    PqrsStatus status, {
    DateTime? resolved,
    String id = 'pqrs-1',
    String clientId = 'client-1',
  }) => PqrsRequest(
    id: id,
    motelId: 'motel-1',
    motelName: 'Motel Uno',
    clientId: clientId,
    clientName: 'Ana',
    ownerId: 'owner-1',
    type: PqrsType.queja,
    subject: 'Ruido en la habitación',
    description: 'Hubo ruido excesivo durante toda la noche.',
    createdAt: DateTime(2026, 11, 1),
    status: status,
    resolvedAt: status == PqrsStatus.resolved ? (resolved ?? resolvedAt) : null,
  );

  late InMemoryPqrsRepository repo;
  late DateTime clockNow;

  PqrsController build(PqrsSession? session, PqrsRequest seed) {
    repo = InMemoryPqrsRepository(seed: [seed]);
    return PqrsController(
      repository: repo,
      session: session,
      clock: () => clockNow,
      initialRequests: [seed],
    );
  }

  setUp(() => clockNow = now);

  group('Cliente: filas permitidas', () {
    for (final status in [PqrsStatus.pending, PqrsStatus.inProgress]) {
      test('comenta en ${status.name} sin cambiar el estado', () async {
        final controller = build(clientSession, request(status));

        final ok = await controller.addUpdate(
          requestId: 'pqrs-1',
          message: 'Sigue el ruido',
        );

        expect(ok, isTrue);
        final updated = controller.byId('pqrs-1');
        expect(updated.status, status);
        expect(updated.trace.single.statusChange, isNull);
        expect(updated.trace.single.author, PqrsActor.client);
        expect(updated.trace.single.authorId, 'client-1');
        expect(repo.appendTraceCalls, 1);
      });
    }

    test(
      'comentar en resolved reabre a in_progress y limpia resolvedAt',
      () async {
        final controller = build(clientSession, request(PqrsStatus.resolved));

        final ok = await controller.addUpdate(
          requestId: 'pqrs-1',
          message: 'No quedó resuelta',
        );

        expect(ok, isTrue);
        final updated = controller.byId('pqrs-1');
        expect(updated.status, PqrsStatus.inProgress);
        expect(updated.resolvedAt, isNull);
        expect(updated.trace.single.statusChange, PqrsStatus.inProgress);
        expect(repo.lastAppend?.clearResolvedAt, isTrue);
        expect(repo.appendTraceCalls, 1);
      },
    );

    test('confirmar y cerrar en resolved fija closedBy client', () async {
      final controller = build(clientSession, request(PqrsStatus.resolved));

      final ok = await controller.closeByClient(requestId: 'pqrs-1');

      expect(ok, isTrue);
      final updated = controller.byId('pqrs-1');
      expect(updated.status, PqrsStatus.closed);
      expect(updated.closedBy, PqrsClosedBy.client);
      expect(updated.trace.single.statusChange, PqrsStatus.closed);
      expect(repo.appendTraceCalls, 1);
    });
  });

  group('Cliente: filas prohibidas', () {
    for (final status in [PqrsStatus.pending, PqrsStatus.inProgress]) {
      test('no puede cerrar en ${status.name}', () async {
        final controller = build(clientSession, request(status));

        final ok = await controller.closeByClient(requestId: 'pqrs-1');

        expect(ok, isFalse);
        expect(controller.error?.kind, PqrsFailureKind.validation);
        expect(repo.appendTraceCalls, 0);
      });
    }

    for (final status in [PqrsStatus.closed, PqrsStatus.rejected]) {
      test('no puede comentar ni cerrar en ${status.name}', () async {
        final controller = build(clientSession, request(status));

        final comment = await controller.addUpdate(
          requestId: 'pqrs-1',
          message: 'Hola',
        );
        final close = await controller.closeByClient(requestId: 'pqrs-1');

        expect(comment, isFalse);
        expect(close, isFalse);
        expect(controller.byId('pqrs-1').status, status);
        expect(repo.appendTraceCalls, 0);
      });
    }

    test('no puede resolver, rechazar ni cerrar por vencimiento', () async {
      final controller = build(clientSession, request(PqrsStatus.inProgress));

      expect(
        await controller.markResolved(requestId: 'pqrs-1', message: 'Listo'),
        isFalse,
      );
      expect(controller.error?.kind, PqrsFailureKind.permission);
      expect(
        await controller.reject(
          requestId: 'pqrs-1',
          message: 'Justificación suficiente',
        ),
        isFalse,
      );
      expect(await controller.closeByTimeout(requestId: 'pqrs-1'), isFalse);
      expect(repo.appendTraceCalls, 0);
    });

    test('no puede comentar la solicitud de otro cliente', () async {
      final controller = build(
        clientSession,
        request(PqrsStatus.pending, clientId: 'client-2'),
      );

      final ok = await controller.addUpdate(
        requestId: 'pqrs-1',
        message: 'Hola',
      );

      expect(ok, isFalse);
      expect(controller.error?.kind, PqrsFailureKind.permission);
    });
  });

  group('Propietario: filas permitidas', () {
    test('el primer avance pasa pending a in_progress', () async {
      final controller = build(ownerSession, request(PqrsStatus.pending));

      final ok = await controller.addUpdate(
        requestId: 'pqrs-1',
        message: 'Revisamos el caso',
      );

      expect(ok, isTrue);
      final updated = controller.byId('pqrs-1');
      expect(updated.status, PqrsStatus.inProgress);
      expect(updated.trace.single.statusChange, PqrsStatus.inProgress);
      expect(updated.trace.single.author, PqrsActor.owner);
      expect(repo.appendTraceCalls, 1);
    });

    test('un avance en in_progress no cambia el estado', () async {
      final controller = build(ownerSession, request(PqrsStatus.inProgress));

      final ok = await controller.addUpdate(
        requestId: 'pqrs-1',
        message: 'Seguimos trabajando',
      );

      expect(ok, isTrue);
      final updated = controller.byId('pqrs-1');
      expect(updated.status, PqrsStatus.inProgress);
      expect(updated.trace.single.statusChange, isNull);
    });

    for (final status in [PqrsStatus.pending, PqrsStatus.inProgress]) {
      test('marcar solucionada desde ${status.name} fija resolvedAt', () async {
        final controller = build(ownerSession, request(status));

        final ok = await controller.markResolved(
          requestId: 'pqrs-1',
          message: 'Ya quedó solucionado',
        );

        expect(ok, isTrue);
        final updated = controller.byId('pqrs-1');
        expect(updated.status, PqrsStatus.resolved);
        expect(updated.resolvedAt, now);
        expect(repo.appendTraceCalls, 1);
      });

      test('rechazar desde ${status.name} con justificación válida', () async {
        final controller = build(ownerSession, request(status));

        final ok = await controller.reject(
          requestId: 'pqrs-1',
          message: 'No aplica a este motel',
        );

        expect(ok, isTrue);
        expect(controller.byId('pqrs-1').status, PqrsStatus.rejected);
        expect(repo.appendTraceCalls, 1);
      });
    }

    test('cierra por vencimiento pasados 7 días desde resolvedAt', () async {
      clockNow = resolvedAt
          .add(pqrsConfirmationDeadline)
          .add(const Duration(minutes: 1));
      final controller = build(ownerSession, request(PqrsStatus.resolved));

      final ok = await controller.closeByTimeout(requestId: 'pqrs-1');

      expect(ok, isTrue);
      final updated = controller.byId('pqrs-1');
      expect(updated.status, PqrsStatus.closed);
      expect(updated.closedBy, PqrsClosedBy.ownerTimeout);
      expect(updated.trace.single.message, pqrsTimeoutClosureMessage);
      expect(
        pqrsTimeoutClosureMessage,
        'Cerrada por vencimiento del plazo de confirmación',
      );
      expect(repo.appendTraceCalls, 1);
    });
  });

  group('Propietario: filas prohibidas', () {
    test('no comenta en resolved', () async {
      final controller = build(ownerSession, request(PqrsStatus.resolved));

      final ok = await controller.addUpdate(
        requestId: 'pqrs-1',
        message: 'Otro mensaje',
      );

      expect(ok, isFalse);
      expect(controller.error?.kind, PqrsFailureKind.validation);
      expect(controller.byId('pqrs-1').trace, isEmpty);
      expect(repo.appendTraceCalls, 0);
    });

    test('no marca solucionada ni rechaza en resolved', () async {
      final controller = build(ownerSession, request(PqrsStatus.resolved));

      expect(
        await controller.markResolved(requestId: 'pqrs-1', message: 'Otra vez'),
        isFalse,
      );
      expect(
        await controller.reject(
          requestId: 'pqrs-1',
          message: 'Justificación suficiente',
        ),
        isFalse,
      );
      expect(repo.appendTraceCalls, 0);
    });

    for (final status in [PqrsStatus.closed, PqrsStatus.rejected]) {
      test('closed y rejected no admiten nada (${status.name})', () async {
        final controller = build(ownerSession, request(status));

        expect(
          await controller.addUpdate(requestId: 'pqrs-1', message: 'Hola'),
          isFalse,
        );
        expect(
          await controller.markResolved(requestId: 'pqrs-1', message: 'Hola'),
          isFalse,
        );
        expect(
          await controller.reject(
            requestId: 'pqrs-1',
            message: 'Justificación suficiente',
          ),
          isFalse,
        );
        expect(await controller.closeByTimeout(requestId: 'pqrs-1'), isFalse);
        expect(controller.byId('pqrs-1').status, status);
        expect(repo.appendTraceCalls, 0);
      });
    }

    test('no puede cerrar confirmando como cliente', () async {
      final controller = build(ownerSession, request(PqrsStatus.resolved));

      final ok = await controller.closeByClient(requestId: 'pqrs-1');

      expect(ok, isFalse);
      expect(controller.error?.kind, PqrsFailureKind.permission);
    });

    test('cierre por vencimiento antes del plazo es rechazado', () async {
      clockNow = resolvedAt.add(const Duration(days: 6, hours: 23));
      final controller = build(ownerSession, request(PqrsStatus.resolved));

      final ok = await controller.closeByTimeout(requestId: 'pqrs-1');

      expect(ok, isFalse);
      expect(controller.byId('pqrs-1').status, PqrsStatus.resolved);
      expect(repo.appendTraceCalls, 0);
    });

    test('cierre por vencimiento justo en el límite es rechazado', () async {
      clockNow = resolvedAt.add(pqrsConfirmationDeadline);
      final controller = build(ownerSession, request(PqrsStatus.resolved));

      expect(await controller.closeByTimeout(requestId: 'pqrs-1'), isFalse);
    });

    test('no cierra por vencimiento en pending ni in_progress', () async {
      final controller = build(ownerSession, request(PqrsStatus.inProgress));

      expect(await controller.closeByTimeout(requestId: 'pqrs-1'), isFalse);
    });

    test('rechazo con justificación corta es rechazado', () async {
      final controller = build(ownerSession, request(PqrsStatus.pending));

      final ok = await controller.reject(requestId: 'pqrs-1', message: 'corto');

      expect(ok, isFalse);
      expect(controller.error?.kind, PqrsFailureKind.validation);
      expect(controller.byId('pqrs-1').status, PqrsStatus.pending);
      expect(repo.appendTraceCalls, 0);
    });
  });

  group('Sesión y administrador', () {
    test('sin sesión devuelve "Debes iniciar sesión"', () async {
      final controller = build(null, request(PqrsStatus.pending));

      final ok = await controller.addUpdate(
        requestId: 'pqrs-1',
        message: 'Hola',
      );
      final created = await controller.createRequest(
        motelId: 'motel-1',
        motelName: 'Motel Uno',
        ownerId: 'owner-1',
        type: PqrsType.queja,
        subject: 'Asunto válido',
        description: 'Descripción suficientemente larga',
      );

      expect(ok, isFalse);
      expect(created, isFalse);
      expect(controller.error?.message, 'Debes iniciar sesión');
      expect(repo.appendTraceCalls, 0);
      expect(repo.createCalls, 0);
    });

    test('el administrador no puede intervenir', () async {
      final controller = build(adminSession, request(PqrsStatus.pending));

      final ok = await controller.addUpdate(
        requestId: 'pqrs-1',
        message: 'Hola',
      );

      expect(ok, isFalse);
      expect(controller.error?.kind, PqrsFailureKind.permission);
    });
  });

  group('Creación', () {
    Future<bool> create(
      PqrsController controller, {
      String motelId = 'motel-1',
      PqrsType? type = PqrsType.queja,
      String subject = 'Asunto válido',
      String description = 'Descripción suficientemente larga',
      int photos = 0,
    }) => controller.createRequest(
      motelId: motelId,
      motelName: 'Motel Uno',
      ownerId: 'owner-1',
      type: type,
      subject: subject,
      description: description,
      attachments: [
        for (var i = 0; i < photos; i++)
          PqrsAttachment(
            id: 'a$i',
            label: 'foto$i.jpg',
            author: PqrsActor.client,
            capturedAt: now,
            seed: i,
          ),
      ],
    );

    test('crea con la sesión como cliente, 3 fotos y estado pending', () async {
      final controller = build(clientSession, request(PqrsStatus.pending));

      final ok = await create(controller, photos: 3, subject: '  Asunto  ');

      expect(ok, isTrue);
      final created = controller.lastCreated;
      expect(created?.clientId, 'client-1');
      expect(created?.clientName, 'Ana');
      expect(created?.status, PqrsStatus.pending);
      expect(created?.subject, 'Asunto');
      expect(created?.attachments, hasLength(3));
      expect(created?.createdAt, now);
      expect(repo.createCalls, 1);
    });

    test('rechaza más de 3 fotos', () async {
      final controller = build(clientSession, request(PqrsStatus.pending));

      expect(await create(controller, photos: 4), isFalse);
      expect(repo.createCalls, 0);
    });

    PqrsController buildWithLimit(int maxPhotos) {
      repo = InMemoryPqrsRepository(seed: const []);
      return PqrsController(
        repository: repo,
        session: clientSession,
        clock: () => clockNow,
        maxPhotos: maxPhotos,
      );
    }

    test('usa el máximo de fotos configurado en Supabase', () async {
      final controller = buildWithLimit(5);

      expect(await create(controller, photos: 5), isTrue);
      expect(await create(controller, photos: 6), isFalse);
      expect(repo.createCalls, 1);
    });

    test('el máximo configurado nunca supera el tope de las reglas', () async {
      final controller = buildWithLimit(50);

      expect(await create(controller, photos: 10), isTrue);
      expect(await create(controller, photos: 11), isFalse);
    });

    test('rechaza asunto de solo espacios o fuera de rango', () async {
      final controller = build(clientSession, request(PqrsStatus.pending));

      expect(await create(controller, subject: '     '), isFalse);
      expect(await create(controller, subject: 'ab'), isFalse);
      expect(await create(controller, subject: 'a' * 101), isFalse);
      expect(await create(controller, subject: 'abc'), isTrue);
    });

    test('rechaza descripción fuera de 10 a 1000 caracteres', () async {
      final controller = build(clientSession, request(PqrsStatus.pending));

      expect(await create(controller, description: 'corta'), isFalse);
      expect(await create(controller, description: 'a' * 1001), isFalse);
      expect(await create(controller, description: 'a' * 10), isTrue);
    });

    test('exige motel y tipo', () async {
      final controller = build(clientSession, request(PqrsStatus.pending));

      expect(await create(controller, motelId: ' '), isFalse);
      expect(await create(controller, type: null), isFalse);
      expect(repo.createCalls, 0);
    });

    test('el propietario no puede crear', () async {
      final controller = build(ownerSession, request(PqrsStatus.pending));

      expect(await create(controller), isFalse);
      expect(controller.error?.kind, PqrsFailureKind.permission);
    });

    test('mensaje de avance de 1 a 1000 caracteres', () async {
      final controller = build(clientSession, request(PqrsStatus.pending));

      expect(
        await controller.addUpdate(requestId: 'pqrs-1', message: '   '),
        isFalse,
      );
      expect(
        await controller.addUpdate(requestId: 'pqrs-1', message: 'a' * 1001),
        isFalse,
      );
      expect(
        await controller.addUpdate(requestId: 'pqrs-1', message: 'a'),
        isTrue,
      );
    });
  });

  group('Carga, error y vacío', () {
    test('carga las solicitudes del cliente y expone estado vacío', () async {
      final controller = build(
        clientSession,
        request(PqrsStatus.pending, clientId: 'client-2'),
      );
      final states = <bool>[];
      controller.addListener(() => states.add(controller.isLoading));

      final ok = await controller.loadRequests();

      expect(ok, isTrue);
      expect(states, contains(true));
      expect(controller.isLoading, isFalse);
      expect(controller.all, isEmpty);
      expect(controller.isEmpty, isTrue);
    });

    test('carga las solicitudes del propietario', () async {
      final controller = build(ownerSession, request(PqrsStatus.pending));

      await controller.loadRequests();

      expect(controller.all, hasLength(1));
      expect(controller.isEmpty, isFalse);
    });

    test('un fallo de conexión se expone y se puede reintentar', () async {
      final controller = build(clientSession, request(PqrsStatus.pending));
      repo.failNext = const PqrsFailure(
        PqrsFailureKind.connection,
        'Sin conexión',
      );

      final first = await controller.addUpdate(
        requestId: 'pqrs-1',
        message: 'Hola',
      );

      expect(first, isFalse);
      expect(controller.error?.kind, PqrsFailureKind.connection);
      expect(controller.error?.isRetryable, isTrue);
      expect(controller.isBusy, isFalse);

      final second = await controller.retry();

      expect(second, isTrue);
      expect(controller.error, isNull);
      expect(controller.byId('pqrs-1').trace, hasLength(1));
      expect(repo.appendTraceCalls, 2);
    });

    test('expone el estado de sincronización del repositorio', () async {
      final controller = build(clientSession, request(PqrsStatus.pending));
      repo.syncStates['pqrs-1'] = const PqrsSyncState.failed('Sin permisos');

      await controller.loadRequests();

      expect(controller.syncOf('pqrs-1').isFailed, isTrue);
      expect(controller.syncOf('pqrs-1').reason, 'Sin permisos');
    });
  });
}
