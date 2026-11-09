import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:machuco/controllers/auth/admin_access_controller.dart';
import 'package:machuco/controllers/auth/auth_routes.dart';
import 'package:machuco/controllers/auth/validators/auth_validators.dart';
import 'package:machuco/database/repository/auth/admin_access_repository.dart';
import 'package:machuco/models/auth/account_status.dart';
import 'package:machuco/models/auth/owner_approval_request.dart';
import 'package:machuco/models/auth/person_type.dart';
import 'package:machuco/models/auth/registered_user.dart';
import 'package:machuco/service/auth/auth_service.dart';
import 'package:machuco/views/admin_access/admin_route_guard.dart';
import 'package:machuco/views/admin_access/owner_approval_detail_page.dart';
import 'package:machuco/views/admin_access/owner_approvals_page.dart';

import 'auth_test_support.dart';

final _company = OwnerApplication(
  uid: 'o1',
  firstNames: 'Ana',
  lastNames: 'Pérez',
  email: 'ana@example.com',
  phoneNumber: '+573001234567',
  personType: PersonType.juridica,
  nit: '900123456-8',
  companyName: 'Moteles del Sur SAS',
  planId: 2,
  createdAt: DateTime(2026, 5, 20),
);

final _natural = OwnerApplication(
  uid: 'o2',
  firstNames: 'Luis',
  lastNames: 'Mora',
  email: 'luis@example.com',
  phoneNumber: '+573009876543',
  personType: PersonType.natural,
  nit: '1020304050-8',
  planId: 1,
  createdAt: DateTime(2026, 5, 21),
);

void main() {
  late InMemoryAdminAccessRepository repository;
  late AdminAccessController controller;

  setUp(() {
    repository = InMemoryAdminAccessRepository([_company, _natural]);
    controller = AdminAccessController(repository: repository);
  });

  Future<void> pumpList(WidgetTester tester) async {
    tester.view.physicalSize = const Size(412, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      testApp(
        OwnerApprovalsPage(controller: controller),
        onGenerateRoute: (settings) {
          if (settings.name == AuthRoutes.adminOwnerApprovalDetail) {
            final args = settings.arguments! as OwnerApprovalDetailArgs;
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => OwnerApprovalDetailPage(
                uid: args.uid,
                controller: args.controller,
              ),
            );
          }
          return null;
        },
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('lista las solicitudes con su contador', (tester) async {
    await pumpList(tester);

    expect(find.text('2 solicitudes pendientes'), findsOneWidget);
    expect(find.text('Moteles del Sur SAS'), findsOneWidget);
    expect(find.text('Persona jurídica'), findsOneWidget);
    expect(find.text('Luis Mora'), findsOneWidget);
    expect(find.text('luis@example.com'), findsOneWidget);
    expect(find.text('21/05/2026'), findsOneWidget);
  });

  testWidgets('estado vacío', (tester) async {
    repository = InMemoryAdminAccessRepository(const []);
    controller = AdminAccessController(repository: repository);
    await pumpList(tester);

    expect(find.text('No hay solicitudes pendientes'), findsOneWidget);
  });

  testWidgets('error con Reintentar', (tester) async {
    repository.failNext = const AdminAccessRepositoryException(
      AdminAccessFailureType.network,
      'No hay conexión. Revisa tu internet e intenta nuevamente.',
    );
    await pumpList(tester);

    expect(find.textContaining('No hay conexión'), findsOneWidget);
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(find.text('2 solicitudes pendientes'), findsOneWidget);
  });

  testWidgets('rechazar exige un motivo válido y actualiza la lista', (
    tester,
  ) async {
    await pumpList(tester);
    await tester.tap(find.text('Luis Mora'));
    await tester.pumpAndSettle();

    expect(find.text('1020304050-8'), findsOneWidget);
    await tester.tap(find.text('Rechazar'));
    await tester.pumpAndSettle();

    final submit = find.text('Confirmar rechazo');
    await tester.tap(submit);
    await tester.pump();
    expect(find.text(AuthValidators.rejectionReason('')!), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Motivo del rechazo'),
      'corto',
    );
    await tester.tap(submit);
    await tester.pump();
    expect(find.text(AuthValidators.rejectionReason('corto')!), findsOneWidget);
    expect(repository.rejected, isEmpty);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Motivo del rechazo'),
      'El NIT no coincide con el RUT.',
    );
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(repository.rejected['o2'], 'El NIT no coincide con el RUT.');
    expect(find.text('1 solicitud pendiente'), findsOneWidget);
    expect(find.text('Luis Mora'), findsNothing);
  });

  testWidgets('aprobar pide confirmación', (tester) async {
    await pumpList(tester);
    await tester.tap(find.text('Moteles del Sur SAS'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Aprobar'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Aprobar'),
      ),
    );
    await tester.pumpAndSettle();

    expect(repository.approvedUids, ['o1']);
    expect(find.text('1 solicitud pendiente'), findsOneWidget);
  });

  testWidgets('si ya fue atendida informa y vuelve a la lista refrescada', (
    tester,
  ) async {
    await pumpList(tester);
    await tester.tap(find.text('Luis Mora'));
    await tester.pumpAndSettle();

    // Otro administrador la atiende mientras se tiene abierto el detalle.
    await repository.approveOwner('o2');

    await tester.tap(find.text('Aprobar'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Aprobar'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('La solicitud ya fue atendida'), findsOneWidget);
    expect(find.text('1 solicitud pendiente'), findsOneWidget);
    expect(find.text('Luis Mora'), findsNothing);
  });

  group('AdminRouteGuard', () {
    AuthSession session(RegisteredUserRole role) => AuthSession(
      userId: 'u',
      name: 'Alguien',
      email: 'a@example.com',
      role: role,
      accessToken: 'a',
      idToken: 'i',
      accountStatus: AccountStatus.active,
    );

    testWidgets('permite a un administrador', (tester) async {
      await tester.pumpWidget(
        testApp(
          AdminRouteGuard(
            sessionLoader: () async => session(RegisteredUserRole.admin),
            child: const Text('contenido admin'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('contenido admin'), findsOneWidget);
    });

    testWidgets('redirige a quien no es administrador', (tester) async {
      var denied = false;
      await tester.pumpWidget(
        testApp(
          AdminRouteGuard(
            sessionLoader: () async => session(RegisteredUserRole.client),
            onDenied: (_) => denied = true,
            child: const Text('contenido admin'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('contenido admin'), findsNothing);
      expect(find.text('Acceso restringido'), findsOneWidget);
      expect(denied, isTrue);
    });
  });
}
