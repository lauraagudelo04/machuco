import 'package:flutter_test/flutter_test.dart';
import 'package:machuco/views/pqrs/data/pqrs_store.dart';
import 'package:machuco/views/pqrs/models/pqrs_models.dart';

PqrsRequest _request({
  String id = 'r1',
  String motelId = 'm1',
  String clientId = 'c1',
  PqrsStatus status = PqrsStatus.pending,
}) {
  return PqrsRequest(
    id: id,
    motelId: motelId,
    motelName: 'Motel Aurora',
    clientId: clientId,
    clientName: 'Ana Perez',
    type: PqrsType.queja,
    subject: 'Ruido en el pasillo',
    description: 'Hubo ruido excesivo durante la noche.',
    createdAt: DateTime(2026, 8, 1, 10),
    status: status,
  );
}

void main() {
  group('PqrsStore - traceability', () {
    test('owner reply appends a trace entry and moves the request to inProgress', () {
      final store = PqrsStore.seeded([_request()]);

      store.addUpdate(
        requestId: 'r1',
        author: PqrsActor.owner,
        message: 'Ya enviamos personal a revisar.',
      );

      final request = store.byId('r1');
      expect(request.status, PqrsStatus.inProgress);
      expect(request.trace, hasLength(1));
      expect(request.trace.single.author, PqrsActor.owner);
      expect(request.trace.single.message, 'Ya enviamos personal a revisar.');
    });

    test('a client comment does not change the status', () {
      final store = PqrsStore.seeded([_request(status: PqrsStatus.inProgress)]);

      store.addUpdate(
        requestId: 'r1',
        author: PqrsActor.client,
        message: 'Sigue el ruido.',
      );

      expect(store.byId('r1').status, PqrsStatus.inProgress);
      expect(store.byId('r1').trace, hasLength(1));
    });

    test('attachments from both actors are preserved in the trace', () {
      final store = PqrsStore.seeded([_request()]);

      store.addUpdate(
        requestId: 'r1',
        author: PqrsActor.client,
        message: 'Foto de lo que encontre.',
        attachments: [PqrsAttachment.simulated(author: PqrsActor.client, label: 'evidencia.jpg')],
      );
      store.addUpdate(
        requestId: 'r1',
        author: PqrsActor.owner,
        message: 'Avance de la reparacion.',
        attachments: [PqrsAttachment.simulated(author: PqrsActor.owner, label: 'avance.jpg')],
      );

      final photos = store.byId('r1').allAttachments;
      expect(photos, hasLength(2));
      expect(photos.map((p) => p.author), containsAll(<PqrsActor>[PqrsActor.client, PqrsActor.owner]));
    });

    test('every status change is recorded in the trace', () {
      final store = PqrsStore.seeded([_request()]);

      store.markResolved(requestId: 'r1', message: 'Solucionado.');

      final entry = store.byId('r1').trace.single;
      expect(entry.statusChange, PqrsStatus.resolved);
      expect(entry.author, PqrsActor.owner);
    });
  });

  group('PqrsStore - closing rules', () {
    test('the client closes a request the owner already resolved', () {
      final store = PqrsStore.seeded([_request(status: PqrsStatus.resolved)]);

      store.closeByClient(requestId: 'r1', message: 'Confirmo la solucion.');

      expect(store.byId('r1').status, PqrsStatus.closed);
      expect(store.byId('r1').trace.single.author, PqrsActor.client);
    });

    test('the client cannot close a request that is still pending', () {
      final store = PqrsStore.seeded([_request(status: PqrsStatus.pending)]);

      expect(
        () => store.closeByClient(requestId: 'r1', message: 'Cierro.'),
        throwsStateError,
      );
      expect(store.byId('r1').status, PqrsStatus.pending);
    });

    test('the owner cannot resolve a request already closed by the client', () {
      final store = PqrsStore.seeded([_request(status: PqrsStatus.closed)]);

      expect(
        () => store.markResolved(requestId: 'r1', message: 'Reabro.'),
        throwsStateError,
      );
    });

    test('a closed request no longer accepts updates', () {
      final store = PqrsStore.seeded([_request(status: PqrsStatus.closed)]);

      expect(
        () => store.addUpdate(requestId: 'r1', author: PqrsActor.owner, message: 'Hola.'),
        throwsStateError,
      );
    });
  });

  group('PqrsStore - queries', () {
    test('filters by motel and by client', () {
      final store = PqrsStore.seeded([
        _request(id: 'a', motelId: 'm1', clientId: 'c1'),
        _request(id: 'b', motelId: 'm2', clientId: 'c1'),
        _request(id: 'c', motelId: 'm1', clientId: 'c2'),
      ]);

      expect(store.byMotel('m1').map((r) => r.id), ['a', 'c']);
      expect(store.byClient('c1').map((r) => r.id), ['a', 'b']);
    });

    test('notifies listeners when a request changes', () {
      final store = PqrsStore.seeded([_request()]);
      var notifications = 0;
      store.addListener(() => notifications++);

      store.addUpdate(requestId: 'r1', author: PqrsActor.owner, message: 'Vamos.');

      expect(notifications, 1);
    });
  });
}
