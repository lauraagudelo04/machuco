import 'package:flutter_test/flutter_test.dart';
import 'package:machuco/service/storage/shared_preferences_local_service.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();
  });

  group('SharedPreferencesLocalService', () {
    test('devuelve null cuando no hay motel filtrado guardado', () async {
      final service = SharedPreferencesLocalService();

      expect(await service.getLastFilterMotelId(), isNull);
    });

    test('guarda y recupera el último motel filtrado', () async {
      final service = SharedPreferencesLocalService();

      await service.setLastFilterMotelId('motel-123');

      expect(await service.getLastFilterMotelId(), 'motel-123');
    });

    test('elimina el motel filtrado guardado', () async {
      final service = SharedPreferencesLocalService();
      await service.setLastFilterMotelId('motel-123');

      await service.clearLastFilterMotelId();

      expect(await service.getLastFilterMotelId(), isNull);
    });
  });
}
