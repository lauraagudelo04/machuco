import 'package:flutter_test/flutter_test.dart';
import 'package:machuco/views/pqrs/models/pqrs_models.dart';

PqrsRequest _request({
  required String id,
  required PqrsStatus status,
  DateTime? createdAt,
  List<PqrsTraceEntry> trace = const [],
}) {
  return PqrsRequest(
    id: id,
    motelId: 'm1',
    motelName: 'Motel Aurora',
    clientId: 'c1',
    clientName: 'Ana Perez',
    type: PqrsType.queja,
    subject: 'Asunto',
    description: 'Descripcion',
    createdAt: createdAt ?? DateTime(2026, 8, 1, 10),
    status: status,
    trace: trace,
  );
}

void main() {
  group('PqrsStats', () {
    test('counts requests per status', () {
      final stats = PqrsStats.from([
        _request(id: '1', status: PqrsStatus.pending),
        _request(id: '2', status: PqrsStatus.inProgress),
        _request(id: '3', status: PqrsStatus.resolved),
        _request(id: '4', status: PqrsStatus.closed),
      ]);

      expect(stats.total, 4);
      expect(stats.countOf(PqrsStatus.pending), 1);
      expect(stats.countOf(PqrsStatus.closed), 1);
      expect(stats.countOf(PqrsStatus.rejected), 0);
    });

    test('attention rate excludes only pending requests', () {
      final stats = PqrsStats.from([
        _request(id: '1', status: PqrsStatus.pending),
        _request(id: '2', status: PqrsStatus.pending),
        _request(id: '3', status: PqrsStatus.inProgress),
        _request(id: '4', status: PqrsStatus.closed),
      ]);

      expect(stats.attentionRate, 0.5);
    });

    test('resolution rate counts resolved and closed requests', () {
      final stats = PqrsStats.from([
        _request(id: '1', status: PqrsStatus.resolved),
        _request(id: '2', status: PqrsStatus.closed),
        _request(id: '3', status: PqrsStatus.inProgress),
        _request(id: '4', status: PqrsStatus.rejected),
      ]);

      expect(stats.resolutionRate, 0.5);
    });

    test('closure rate only counts requests confirmed by the client', () {
      final stats = PqrsStats.from([
        _request(id: '1', status: PqrsStatus.resolved),
        _request(id: '2', status: PqrsStatus.closed),
      ]);

      expect(stats.closureRate, 0.5);
    });

    test('an empty list yields zero rates instead of dividing by zero', () {
      final stats = PqrsStats.from(const []);

      expect(stats.total, 0);
      expect(stats.attentionRate, 0);
      expect(stats.resolutionRate, 0);
      expect(stats.closureRate, 0);
      expect(stats.averageFirstResponse, isNull);
    });

    test('average first response uses the first owner entry of each request', () {
      final stats = PqrsStats.from([
        _request(
          id: '1',
          status: PqrsStatus.inProgress,
          createdAt: DateTime(2026, 8, 1, 10),
          trace: [
            PqrsTraceEntry(
              id: 't1',
              author: PqrsActor.client,
              message: 'Agrego una foto.',
              createdAt: DateTime(2026, 8, 1, 11),
            ),
            PqrsTraceEntry(
              id: 't2',
              author: PqrsActor.owner,
              message: 'Vamos en camino.',
              createdAt: DateTime(2026, 8, 1, 12),
            ),
          ],
        ),
        _request(
          id: '2',
          status: PqrsStatus.inProgress,
          createdAt: DateTime(2026, 8, 1, 10),
          trace: [
            PqrsTraceEntry(
              id: 't3',
              author: PqrsActor.owner,
              message: 'Revisando.',
              createdAt: DateTime(2026, 8, 1, 14),
            ),
          ],
        ),
        _request(id: '3', status: PqrsStatus.pending),
      ]);

      expect(stats.averageFirstResponse, const Duration(hours: 3));
    });
  });
}
