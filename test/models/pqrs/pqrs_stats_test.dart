import 'package:flutter_test/flutter_test.dart';
import 'package:machuco/models/pqrs/pqrs.dart';

PqrsRequest _request(
  String id,
  PqrsStatus status, {
  PqrsClosedBy? closedBy,
  DateTime? resolvedAt,
}) => PqrsRequest(
  id: id,
  motelId: 'm1',
  motelName: 'Motel',
  clientId: 'c1',
  clientName: 'Cliente',
  ownerId: 'o1',
  type: PqrsType.queja,
  subject: 'Asunto',
  description: 'Descripcion larga',
  createdAt: DateTime(2026, 11, 1),
  status: status,
  closedBy: closedBy,
  resolvedAt: resolvedAt,
);

void main() {
  test('zero requests give zero rates', () {
    final stats = PqrsStats.from(const []);
    expect(stats.total, 0);
    expect(stats.solutionRate, 0);
    expect(stats.closureRate, 0);
    expect(stats.closedByTimeoutCount, 0);
  });

  test('mixed statuses', () {
    final stats = PqrsStats.from([
      _request('1', PqrsStatus.pending),
      _request('2', PqrsStatus.inProgress),
      _request('3', PqrsStatus.resolved),
      _request('4', PqrsStatus.closed, closedBy: PqrsClosedBy.client),
      _request('5', PqrsStatus.rejected),
    ]);
    expect(stats.total, 5);
    expect(stats.countOf(PqrsStatus.pending), 1);
    expect(stats.countOf(PqrsStatus.rejected), 1);
    expect(stats.solutionRate, 2 / 5);
    expect(stats.closureRate, 1 / 2);
  });

  test('timeout closures stay out of the closure numerator', () {
    final stats = PqrsStats.from([
      _request('1', PqrsStatus.closed, closedBy: PqrsClosedBy.client),
      _request('2', PqrsStatus.closed, closedBy: PqrsClosedBy.ownerTimeout),
      _request('3', PqrsStatus.resolved),
      _request('4', PqrsStatus.pending),
    ]);
    expect(stats.closedByTimeoutCount, 1);
    expect(stats.closureRate, 1 / 3);
    expect(stats.solutionRate, 3 / 4);
  });

  test('closed without closedBy counts as client', () {
    final stats = PqrsStats.from([_request('1', PqrsStatus.closed)]);
    expect(stats.closureRate, 1);
  });

  test('closedBy keys round trip', () {
    expect(PqrsClosedBy.fromKey('client'), PqrsClosedBy.client);
    expect(PqrsClosedBy.fromKey('owner_timeout'), PqrsClosedBy.ownerTimeout);
    expect(PqrsClosedBy.fromKey(null), isNull);
  });

  group('canBeClosedByOwnerTimeout', () {
    final resolvedAt = DateTime(2026, 11, 1);
    final request = _request('1', PqrsStatus.resolved, resolvedAt: resolvedAt);

    test('expired deadline', () {
      expect(request.confirmationDeadline, DateTime(2026, 11, 8));
      expect(request.canBeClosedByOwnerTimeout(DateTime(2026, 11, 9)), isTrue);
    });

    test('deadline not reached', () {
      expect(request.canBeClosedByOwnerTimeout(DateTime(2026, 11, 7)), isFalse);
      expect(request.canBeClosedByOwnerTimeout(DateTime(2026, 11, 8)), isFalse);
    });

    test('not resolved or without resolvedAt', () {
      final inProgress = _request(
        '2',
        PqrsStatus.inProgress,
        resolvedAt: resolvedAt,
      );
      final noDate = _request('3', PqrsStatus.resolved);
      expect(inProgress.canBeClosedByOwnerTimeout(DateTime(2027)), isFalse);
      expect(noDate.canBeClosedByOwnerTimeout(DateTime(2027)), isFalse);
    });
  });
}
