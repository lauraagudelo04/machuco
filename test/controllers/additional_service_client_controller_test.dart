import 'package:flutter_test/flutter_test.dart';
import 'package:machuco/controllers/additional_service/client_view/additional_service_client_controller.dart';
import 'package:machuco/models/additional_service/additional_service.dart';
import 'package:machuco/models/additional_service/additional_service_store.dart';

void main() {
  test('administra y confirma la selección temporal del cliente', () {
    const service = AdditionalService(
      id: 'breakfast',
      icon: AdditionalServiceIcon.miscellaneous,
      name: 'Desayuno',
      description: 'Desayuno para dos',
      category: 'Alimentación',
      price: 25000,
      active: true,
    );
    final controller = AdditionalServiceClientController(
      store: AdditionalServiceStore(
        initialServices: const [service],
        initialSelectedServiceIds: const [],
      ),
    );
    addTearDown(controller.dispose);

    controller.beginSelection();
    controller.toggleDraftSelected(service);

    expect(controller.isDraftSelected(service), isTrue);
    expect(controller.draftSelectedCount, 1);
    expect(controller.draftSelectedTotal, 25000);
    expect(controller.selectedServices, isEmpty);

    controller.confirmSelection();

    expect(controller.selectedServices, [service]);
    expect(controller.selectedTotal, 25000);
  });
}
