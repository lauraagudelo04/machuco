import 'package:flutter_test/flutter_test.dart';
import 'package:machuco/controllers/motel/motel_controller.dart';
import 'package:machuco/database/repository/motel/motel_repository.dart';
import 'package:machuco/models/motel/motel_model.dart';

class _Repository implements MotelRepository {
  bool queriedMine = false;
  bool queriedAll = false;

  @override
  Future<List<Motel>> getMyMotels() async {
    queriedMine = true;
    return [];
  }

  @override
  Future<List<Motel>> getMotels() async {
    queriedAll = true;
    return [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('consulta del propietario conectado evita la operación de admin', () async {
    final repository = _Repository();
    final controller = MotelController(
      repository: repository,
      currentUserId: () => 'owner',
    );
    await controller.getMotelsByOwnerId('owner');
    expect(repository.queriedMine, isTrue);
    expect(repository.queriedAll, isFalse);
  });

  test('consulta de otro propietario conserva el flujo administrativo', () async {
    final repository = _Repository();
    final controller = MotelController(
      repository: repository,
      currentUserId: () => 'admin',
    );
    await controller.getMotelsByOwnerId('owner');
    expect(repository.queriedAll, isTrue);
    expect(repository.queriedMine, isFalse);
  });
}
