import 'package:flutter_test/flutter_test.dart';
import 'package:machuco/service/storage/shared_preferences_local_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('SharedPreferencesLocalService', () {
    test('devuelve null cuando la clave no existe', () async {
      final service = SharedPreferencesLocalService(namespace: 'bookings');

      expect(await service.getString('lastFilterMotelId'), isNull);
      expect(await service.getBool('onboardingSeen'), isNull);
      expect(await service.containsKey('lastFilterMotelId'), isFalse);
    });

    test('guarda y recupera todos los tipos soportados', () async {
      final service = SharedPreferencesLocalService(namespace: 'bookings');

      await service.setString('text', 'motel-123');
      await service.setBool('flag', true);
      await service.setInt('count', 3);
      await service.setDouble('ratio', 0.5);
      await service.setStringList('ids', ['a', 'b']);

      expect(await service.getString('text'), 'motel-123');
      expect(await service.getBool('flag'), isTrue);
      expect(await service.getInt('count'), 3);
      expect(await service.getDouble('ratio'), 0.5);
      expect(await service.getStringList('ids'), ['a', 'b']);
    });

    test('persiste las claves con el prefijo del namespace', () async {
      final service = SharedPreferencesLocalService(namespace: 'bookings');

      await service.setString('lastFilterMotelId', 'motel-123');

      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getString('bookings.lastFilterMotelId'), 'motel-123');
    });

    test('lee valores existentes con la API clásica', () async {
      SharedPreferences.setMockInitialValues({
        'bookings.lastFilterMotelId': 'motel-9',
      });
      final service = SharedPreferencesLocalService(namespace: 'bookings');

      expect(await service.getString('lastFilterMotelId'), 'motel-9');
    });

    test('namespaces distintos no colisionan con la misma clave', () async {
      final bookings = SharedPreferencesLocalService(namespace: 'bookings');
      final pqrs = SharedPreferencesLocalService(namespace: 'pqrs');

      await bookings.setString('lastFilter', 'motel-1');
      await pqrs.setString('lastFilter', 'open');

      expect(await bookings.getString('lastFilter'), 'motel-1');
      expect(await pqrs.getString('lastFilter'), 'open');
    });

    test('remove elimina solo la clave indicada', () async {
      final service = SharedPreferencesLocalService(namespace: 'bookings');
      await service.setString('a', '1');
      await service.setString('b', '2');

      await service.remove('a');

      expect(await service.getString('a'), isNull);
      expect(await service.getString('b'), '2');
    });

    test('clear elimina solo las claves de su namespace', () async {
      final bookings = SharedPreferencesLocalService(namespace: 'bookings');
      final pqrs = SharedPreferencesLocalService(namespace: 'pqrs');
      await bookings.setString('a', '1');
      await bookings.setBool('b', true);
      await pqrs.setString('a', 'keep');

      await bookings.clear();

      expect(await bookings.containsKey('a'), isFalse);
      expect(await bookings.containsKey('b'), isFalse);
      expect(await pqrs.getString('a'), 'keep');
    });

    test('usa la instancia inyectada si se provee', () async {
      SharedPreferences.setMockInitialValues({'auth.seen': true});
      final preferences = await SharedPreferences.getInstance();
      final service = SharedPreferencesLocalService(
        namespace: 'auth',
        preferences: preferences,
      );

      expect(await service.getBool('seen'), isTrue);
    });

    test('rechaza namespaces o claves con formato inválido', () async {
      expect(
        () => SharedPreferencesLocalService(namespace: ''),
        throwsArgumentError,
      );
      expect(
        () => SharedPreferencesLocalService(namespace: 'bookings.client'),
        throwsArgumentError,
      );
      expect(
        () => SharedPreferencesLocalService(namespace: 'Bookings'),
        throwsArgumentError,
      );

      final service = SharedPreferencesLocalService(namespace: 'bookings');
      expect(() => service.getString('a.b'), throwsArgumentError);
    });
  });
}
