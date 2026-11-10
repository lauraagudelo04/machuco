import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:machuco/core/design_system/design_system.dart';
import 'package:machuco/controllers/additional_service/system_admin_view/additional_service_system_administrator_controller.dart';
import 'package:machuco/database/repository/additional_service/additional_service_category_repository.dart';
import 'package:machuco/database/repository/additional_service/additional_service_cloud_repository.dart';
import 'package:machuco/database/repository/additional_service/additional_service_repository.dart';
import 'package:machuco/models/additional_service/additional_service.dart';
import 'package:machuco/models/additional_service/additional_service_category.dart';
import 'package:machuco/models/motel/motel_model.dart';
import 'package:machuco/views/motel/client_view/client_motel_detail_page.dart';

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
  _FakeCloud(this.services, {this.failure});

  final List<AdditionalService> services;
  final AdditionalServiceCloudException? failure;

  @override
  Future<List<AdditionalService>> listByMotel(String motelId) async {
    if (failure != null) throw failure!;
    return services.where((s) => s.motelId == motelId).toList();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _motel = Motel(
  id: 'm1',
  ownerId: 'o1',
  name: 'Motel Luna',
  email: 'luna@example.com',
  roomCount: 10,
  nit: '900123',
  address: 'Calle 1 # 2-3',
  phone: '3001234567',
  paymentMethods: ['Efectivo'],
  imageUrls: [],
);

AdditionalServiceSystemAdministratorController _controller(_FakeCloud cloud) =>
    AdditionalServiceSystemAdministratorController(
      motelId: 'm1',
      serviceRepository: _FakeLocal(),
      categoryRepository: _FakeCategories(),
      cloudRepository: cloud,
      currentUserId: () => null,
    );

Future<void> _pump(WidgetTester tester, _FakeCloud cloud) async {
  tester.view.physicalSize = const Size(800, 6000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: ClientMotelDetailPage(
        motel: _motel,
        additionalServiceController: _controller(cloud),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('muestra solo los servicios activos del motel con su precio', (
    tester,
  ) async {
    await _pump(
      tester,
      _FakeCloud(const [
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
        AdditionalService(
          id: 's3',
          motelId: 'otro',
          name: 'Karaoke',
          description: 'Sala de karaoke',
          category: 'Entretenimiento',
          price: 15000,
          active: true,
        ),
      ]),
    );

    expect(find.text('Servicios Adicionales'), findsOneWidget);
    expect(find.text('Jacuzzi'), findsOneWidget);
    expect(find.text('Jacuzzi privado'), findsOneWidget);
    expect(find.text('\$30.000'), findsOneWidget);
    expect(find.text('Sauna'), findsNothing);
    expect(find.text('Karaoke'), findsNothing);
  });

  testWidgets('sin servicios muestra un mensaje', (tester) async {
    await _pump(tester, _FakeCloud(const []));

    expect(
      find.text('No hay servicios adicionales disponibles para este motel.'),
      findsOneWidget,
    );
  });

  testWidgets('si la consulta falla explica el motivo', (tester) async {
    await _pump(
      tester,
      _FakeCloud(
        const [],
        failure: const AdditionalServiceCloudException(
          AdditionalServiceCloudFailureType.network,
          'Sin conexión con Firebase. Inténtalo de nuevo.',
        ),
      ),
    );

    expect(
      find.text('Sin conexión con Firebase. Inténtalo de nuevo.'),
      findsOneWidget,
    );
  });
}
