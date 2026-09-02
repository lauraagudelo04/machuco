import 'package:flutter_test/flutter_test.dart';
import 'package:machuco/controllers/additional_service/system_admin_view/additional_service_system_administrator_controller.dart';
import 'package:machuco/models/additional_service/additional_service_store.dart';

void main() {
  group('AdditionalServiceSystemAdministratorController', () {
    late AdditionalServiceSystemAdministratorController controller;

    setUp(() {
      controller = AdditionalServiceSystemAdministratorController(
        store: AdditionalServiceStore(
          initialServices: const [],
          initialSelectedServiceIds: const [],
        ),
      );
    });

    tearDown(() => controller.dispose());

    test('rechaza datos inválidos y notifica los errores', () {
      var notifications = 0;
      controller.addListener(() => notifications++);

      final saved = controller.save(
        name: ' ',
        description: '',
        category: ' ',
        priceText: '-10',
      );

      expect(saved, isFalse);
      expect(controller.services, isEmpty);
      expect(controller.nameError, isNotNull);
      expect(controller.descriptionError, isNotNull);
      expect(controller.categoryError, isNotNull);
      expect(controller.priceError, isNotNull);
      expect(notifications, 1);
    });

    test('normaliza y crea un servicio válido', () {
      final saved = controller.save(
        name: '  Desayuno  ',
        description: '  Desayuno para dos  ',
        category: '  Alimentación  ',
        priceText: '25000',
      );

      expect(saved, isTrue);
      expect(controller.services, hasLength(1));
      expect(controller.services.single.name, 'Desayuno');
      expect(controller.services.single.price, 25000);
    });
  });
}
