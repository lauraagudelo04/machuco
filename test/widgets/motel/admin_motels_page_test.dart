import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:machuco/controllers/motel/motel_controller.dart';
import 'package:machuco/controllers/owner_management/owner_controller.dart';
import 'package:machuco/core/design_system/design_system.dart';
import 'package:machuco/database/repository/motel/motel_repository.dart';
import 'package:machuco/models/motel/motel_model.dart';
import 'package:machuco/models/owner_management/document_type.dart';
import 'package:machuco/models/owner_management/owner.dart';
import 'package:machuco/views/motel/system_admin_view/admin_motels_page.dart';

Motel _motel(String id, String ownerId, {bool isAvailable = true}) => Motel(
  id: id,
  ownerId: ownerId,
  name: 'Motel $id',
  email: '$id@motel.com',
  roomCount: 10,
  nit: '90012345$id-1',
  address: 'Calle $id',
  phone: '+57 3001234567',
  paymentMethods: const ['Efectivo'],
  imageUrls: const [],
  isAvailable: isAvailable,
);

class _FakeMotelRepository implements MotelRepository {
  _FakeMotelRepository(this.motels);

  List<Motel> motels;
  Object? readError;
  Object? writeError;
  final List<Motel> adminUpdates = [];

  @override
  Future<List<Motel>> getMotels() async {
    final error = readError;
    if (error != null) throw error;
    return motels;
  }

  @override
  Future<Motel> updateMotelAsAdmin(Motel motel) async {
    final error = writeError;
    if (error != null) throw error;
    adminUpdates.add(motel);
    return motel;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeOwnerController implements OwnerController {
  _FakeOwnerController(this._owners);

  final List<Owner> _owners;

  @override
  Future<void> init() async {}

  @override
  List<Owner> get owners => _owners;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _FakeMotelRepository repository;
  Owner owner(String id, String fullName) => Owner(
    id: id,
    fullName: fullName,
    documentType: DocumentType.citizenshipCard,
    documentNumber: '1020304050',
    email: '$id@machuco.com',
    phone: '3001234567',
  );
  final owners = [owner('owner-a', 'Ana Gómez'), owner('owner-b', 'Beto Ruiz')];

  setUp(() {
    repository = _FakeMotelRepository([
      _motel('1', 'owner-a'),
      _motel('2', 'owner-b'),
      _motel('3', 'owner-b', isAvailable: false),
    ]);
  });

  Future<void> pumpPage(WidgetTester tester, {String? initialOwnerId}) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        // Solo se prueba la pestaña de moteles: las demás pestañas son de
        // otros módulos y no hacen falta aquí.
        home: AdminMotelsPage(
          initialOwnerId: initialOwnerId,
          motelController: MotelController(repository: repository),
          ownerController: _FakeOwnerController(owners),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('sin propietario inicial muestra los moteles de todos', (
    tester,
  ) async {
    await pumpPage(tester);

    expect(find.text('Todos los moteles'), findsOneWidget);
    expect(find.text('Motel 1'), findsOneWidget);
    expect(find.text('Motel 2'), findsOneWidget);
    expect(find.text('Motel 3'), findsOneWidget);
    expect(find.textContaining('Dueño: Ana Gómez'), findsOneWidget);
    expect(find.textContaining('Dueño: Beto Ruiz'), findsNWidgets(2));
  });

  testWidgets('con propietario inicial filtra solo sus moteles', (
    tester,
  ) async {
    await pumpPage(tester, initialOwnerId: 'owner-a');

    expect(find.text('Motel 1'), findsOneWidget);
    expect(find.text('Motel 2'), findsNothing);
    expect(find.text('Motel 3'), findsNothing);
  });

  testWidgets(
    'bloquear guarda en el servidor el motel correcto aun filtrando',
    (tester) async {
      await pumpPage(tester);

      await tester.enterText(find.byType(TextField).last, 'Motel 2');
      await tester.pumpAndSettle();
      expect(find.text('Motel 1'), findsNothing);

      await tester.tap(find.byTooltip('Bloquear establecimiento'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sí, bloquear'));
      await tester.pumpAndSettle();

      expect(repository.adminUpdates, hasLength(1));
      expect(repository.adminUpdates.single.id, '2');
      expect(repository.adminUpdates.single.isAvailable, isFalse);
      expect(find.text('Bloqueado'), findsOneWidget);
    },
  );

  testWidgets('si el servidor rechaza el bloqueo, el motel no cambia', (
    tester,
  ) async {
    repository.writeError = const MotelRepositoryException(
      'Solo un administrador puede editar moteles',
    );
    await pumpPage(tester, initialOwnerId: 'owner-a');

    await tester.tap(find.byTooltip('Bloquear establecimiento'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sí, bloquear'));
    await tester.pumpAndSettle();

    expect(
      find.text('Solo un administrador puede editar moteles'),
      findsOneWidget,
    );
    expect(find.text('Bloqueado'), findsNothing);
    expect(find.byTooltip('Bloquear establecimiento'), findsOneWidget);
  });

  testWidgets('sin red y sin caché muestra el error con reintento', (
    tester,
  ) async {
    repository.readError = const MotelRepositoryException(
      'No fue posible consultar los moteles',
    );
    await pumpPage(tester);

    expect(find.text('No fue posible consultar los moteles'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);

    repository.readError = null;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();

    expect(find.text('Motel 1'), findsOneWidget);
  });
}
