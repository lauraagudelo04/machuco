import 'package:flutter_test/flutter_test.dart';
import 'package:machuco/database/repository/auth/user_document_tree_removal.dart';

/// `users/{uid}` en memoria: subcolección -> ids de documentos.
class _FakeTree {
  _FakeTree(this.subcollections);

  final Map<String, List<String>> subcollections;
  bool profileExists = true;
  final log = <String>[];

  /// Falla el lote número [failOnBatch] (1-based), una sola vez.
  int? failOnBatch;
  int _batches = 0;

  Future<List<String>> fetchPage(String name, int limit) async {
    final ids = subcollections[name] ?? const <String>[];
    return ids.take(limit).map((id) => '$name/$id').toList();
  }

  Future<void> deleteBatch(List<String> references) async {
    _batches++;
    if (_batches == failOnBatch) {
      failOnBatch = null;
      throw StateError('sin red');
    }
    for (final reference in references) {
      final [name, id] = reference.split('/');
      subcollections[name]!.remove(id);
    }
    log.add('batch:${references.length}');
  }

  Future<void> deleteProfile() async {
    profileExists = false;
    log.add('profile');
  }

  bool get isEmpty =>
      !profileExists && subcollections.values.every((ids) => ids.isEmpty);

  Future<void> remove({int batchSize = 3}) => removeUserDocumentTree<String>(
    fetchPage: fetchPage,
    deleteBatch: deleteBatch,
    deleteProfileDocument: deleteProfile,
    batchSize: batchSize,
  );
}

List<String> _ids(int count) => [for (var i = 0; i < count; i++) 'd$i'];

void main() {
  test('[DA-15] cliente con subcolecciones: no queda nada bajo users/{uid} y '
      'el perfil se borra al final', () async {
    final tree = _FakeTree({
      'notificationReads': _ids(7),
      'devices': _ids(2),
      'subscriptions': _ids(3),
    });

    await tree.remove();

    expect(tree.isEmpty, isTrue);
    expect(tree.log.last, 'profile');
    // 7 lecturas en lotes de 3 (3 + 3 + 1), 2 dispositivos, 3 suscripciones
    // (lote lleno y una página vacía de cierre).
    expect(tree.log, [
      'batch:3',
      'batch:3',
      'batch:1',
      'batch:2',
      'batch:3',
      'profile',
    ]);
  });

  test('solo borra las subcolecciones permitidas (los pagos se conservan)', () {
    expect(userOwnedSubcollections, [
      'notificationReads',
      'devices',
      'subscriptions',
    ]);
    expect(userOwnedSubcollections, isNot(contains('payments')));
    expect(userOwnedSubcollections, isNot(contains('subscriptionPayments')));
  });

  test(
    'si un lote falla, el perfil no se borra y el reintento continúa',
    () async {
      final tree = _FakeTree({
        'notificationReads': _ids(4),
        'devices': _ids(1),
        'subscriptions': _ids(1),
      })..failOnBatch = 2;

      await expectLater(tree.remove(), throwsStateError);
      expect(tree.profileExists, isTrue);
      expect(tree.subcollections['notificationReads'], hasLength(1));

      await tree.remove();
      expect(tree.isEmpty, isTrue);
    },
  );

  test('reintento sin subcolecciones ni perfil: es idempotente', () async {
    final tree = _FakeTree({
      'notificationReads': [],
      'devices': [],
      'subscriptions': [],
    })..profileExists = false;

    await tree.remove();

    expect(tree.isEmpty, isTrue);
    expect(tree.log, ['profile']);
  });
}
