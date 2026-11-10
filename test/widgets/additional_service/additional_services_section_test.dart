import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:machuco/controllers/additional_service/system_admin_view/additional_service_system_administrator_controller.dart';
import 'package:machuco/core/design_system/design_system.dart';
import 'package:machuco/database/repository/additional_service/additional_service_category_repository.dart';
import 'package:machuco/database/repository/additional_service/additional_service_cloud_repository.dart';
import 'package:machuco/database/repository/additional_service/additional_service_repository.dart';
import 'package:machuco/models/additional_service/additional_service.dart';
import 'package:machuco/models/additional_service/additional_service_category.dart';
import 'package:machuco/widgets/additional_service/additional_services_section.dart';

class _FakeLocal implements AdditionalServiceRepository {
  @override
  Future<List<AdditionalService>> findAll() async => const [];

  @override
  Future<void> replaceForMotel(
    String motelId,
    List<AdditionalService> services,
  ) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeCategories implements AdditionalServiceCategoryRepository {
  @override
  Future<List<AdditionalServiceCategory>> getCategories() async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeCloud implements AdditionalServiceCloudRepository {
  _FakeCloud(this.services);

  final List<AdditionalService> services;

  @override
  Future<List<AdditionalService>> listByMotel(String motelId) async =>
      services.where((s) => s.motelId == motelId).toList();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('la sección muestra solo los servicios activos del motel', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 6000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    final controller = AdditionalServiceSystemAdministratorController(
      motelId: 'm1',
      serviceRepository: _FakeLocal(),
      categoryRepository: _FakeCategories(),
      cloudRepository: _FakeCloud(const [
        AdditionalService(
          id: 's1',
          motelId: 'm1',
          name: 'Jacuzzi',
          description: 'Jacuzzi privado',
          category: 'Bienestar',
          price: 30000,
          active: true,
        ),
        AdditionalService(
          id: 's2',
          motelId: 'm1',
          name: 'Sauna',
          description: 'Sauna seco',
          category: 'Bienestar',
          price: 20000,
          active: false,
        ),
      ]),
      currentUserId: () => null,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: AdditionalServicesSection(
            motelId: 'm1',
            controller: controller,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Servicios Adicionales'), findsOneWidget);
    expect(find.text('Jacuzzi'), findsOneWidget);
    expect(find.text('\$30.000'), findsOneWidget);
    expect(find.text('Sauna'), findsNothing);
  });
}
