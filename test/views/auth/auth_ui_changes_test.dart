import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:machuco/controllers/auth/admin_access_controller.dart';
import 'package:machuco/controllers/auth/auth_routes.dart';
import 'package:machuco/controllers/auth/login_controller.dart';
import 'package:machuco/controllers/auth/user_profile_controller.dart';
import 'package:machuco/core/design_system/design_system.dart';
import 'package:machuco/database/repository/auth/admin_access_repository.dart';
import 'package:machuco/database/repository/auth/user_profile_repository.dart';
import 'package:machuco/models/auth/account_status.dart';
import 'package:machuco/models/auth/owner_approval_request.dart';
import 'package:machuco/models/auth/person_type.dart';
import 'package:machuco/models/auth/registered_user.dart';
import 'package:machuco/models/auth/subscription_plan_option.dart';
import 'package:machuco/models/auth/user_profile.dart';
import 'package:machuco/models/owner_management/document_type.dart';
import 'package:machuco/service/auth/auth_service.dart';
import 'package:machuco/views/admin_access/admin_profile_page.dart';
import 'package:machuco/views/admin_access/owner_application_format.dart';
import 'package:machuco/views/admin_access/owner_approval_detail_page.dart';
import 'package:machuco/views/motel/owner_view/owner_profile_page.dart';
import 'package:machuco/views/register/plan_selector.dart';
import 'package:machuco/views/register/register_form.dart';
import 'package:machuco/widgets/auth/delete_account_action.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_test_support.dart';

class _Profiles implements UserProfileRepository {
  _Profiles(this.profile);

  final UserProfile profile;

  @override
  Future<UserProfile?> getProfile(String uid) async => profile;

  @override
  Future<void> createProfile(UserProfile profile) async {}

  @override
  Future<void> updateProfile({
    required String uid,
    required String fullName,
    required String phoneNumber,
  }) async {}

  @override
  Future<void> clearMustChangePassword(String uid) async {}

  @override
  Future<void> deleteProfile(String uid) async {}
}

UserProfileController _profileController(RegisteredUserRole role) {
  final controller = UserProfileController(
    repository: _Profiles(
      UserProfile(
        uid: 'u1',
        fullName: 'Persona Uno',
        email: 'uno@machuco.com',
        phoneNumber: '+573009998877',
        role: role,
        accountStatus: AccountStatus.active,
      ),
    ),
    currentUserId: () => 'u1',
  );
  addTearDown(controller.dispose);
  return controller;
}

void _bigView(WidgetTester tester, {double height = 2400}) {
  tester.view.physicalSize = Size(700, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('DA-13: "Eliminar cuenta" en los perfiles', () {
    testWidgets('Propietario activo', (tester) async {
      _bigView(tester);
      final login = buildTestController(FakeAuthService());
      await tester.pumpWidget(
        testApp(
          OwnerProfilePage(
            controller: _profileController(RegisteredUserRole.owner),
            loginController: login,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Eliminar cuenta'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('delete-account-action')));
      await tester.pumpAndSettle();
      expect(find.text('Eliminar definitivamente'), findsOneWidget);
    });

    testWidgets('Administrador (anonimiza) y enlace a Administradores', (
      tester,
    ) async {
      _bigView(tester);
      final login = buildTestController(FakeAuthService());
      String? pushed;
      await tester.pumpWidget(
        testApp(
          AdminProfilePage(
            controller: _profileController(RegisteredUserRole.admin),
            loginController: login,
          ),
          onGenerateRoute: (settings) {
            pushed = settings.name;
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => const Scaffold(body: Text('lista de admins')),
            );
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('delete-account-action')));
      await tester.pumpAndSettle();
      expect(find.text('Eliminar definitivamente'), findsOneWidget);
      expect(find.textContaining('anonimizará'), findsOneWidget);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('admin-profile-administrators')),
      );
      await tester.pumpAndSettle();
      expect(pushed, AuthRoutes.adminAdministrators);
    });

    testWidgets('la acción es de peligro y Cancelar no elimina', (
      tester,
    ) async {
      _bigView(tester);
      final auth = FakeAuthService();
      await tester.pumpWidget(
        testApp(
          Scaffold(
            body: DeleteAccountAction(controller: buildTestController(auth)),
          ),
        ),
      );
      final button = tester.widget<AppButton>(find.byType(AppButton));
      expect(button.variant, AppButtonVariant.destructive);
      await tester.tap(find.byType(AppButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(auth.deletedWithPasswords, isEmpty);
    });

    testWidgets('error de red: "Reintentar" repite sin cambiar la hoja', (
      tester,
    ) async {
      _bigView(tester);
      final auth = FakeAuthService()
        ..deleteFailure = const AuthFailure(
          AuthFailureType.network,
          'No hay conexión.',
        );
      await tester.pumpWidget(
        testApp(
          Scaffold(
            body: DeleteAccountAction(controller: buildTestController(auth)),
          ),
        ),
      );
      await tester.tap(find.byType(AppButton));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Contraseña actual'),
        'Segura12345',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Escribe ELIMINAR para confirmar'),
        'ELIMINAR',
      );
      await tester.pump();
      await tester.tap(find.text('Eliminar definitivamente'));
      await tester.pumpAndSettle();

      expect(find.text('No hay conexión.'), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);
      expect(auth.deletedWithPasswords, isEmpty);

      // El reintento vuelve a llamar al servicio; la hoja sigue abierta.
      auth.deleteFailure = const AuthFailure(
        AuthFailureType.invalidCredentials,
        'Contraseña incorrecta.',
      );
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(find.text('Contraseña incorrecta.'), findsOneWidget);
      expect(find.text('Reintentar'), findsNothing);
      expect(find.text('Eliminar definitivamente'), findsOneWidget);
    });
  });

  group('detalle de la solicitud de propietario', () {
    final application = OwnerApplication(
      uid: 'o1',
      firstNames: 'Ana',
      lastNames: 'Pérez',
      email: 'ana@example.com',
      phoneNumber: '+573001234567',
      personType: PersonType.juridica,
      nit: '900123456-8',
      companyName: 'Moteles del Sur SAS',
      planId: 2,
      documentType: DocumentType.citizenshipCard,
      documentNumber: '1020304050',
      createdAt: DateTime(2026, 5, 20),
    );

    late InMemoryAdminAccessRepository repository;
    late AdminAccessController controller;

    setUp(() {
      repository = InMemoryAdminAccessRepository([application]);
      controller = AdminAccessController(
        repository: repository,
        loadPlans: () async => const [
          SubscriptionPlanOption(id: 1, name: 'Básico'),
          SubscriptionPlanOption(id: 2, name: 'Premium'),
        ],
      );
    });

    Future<void> pumpDetail(WidgetTester tester) async {
      _bigView(tester);
      await controller.loadPendingOwners();
      await tester.pumpWidget(
        testApp(OwnerApprovalDetailPage(uid: 'o1', controller: controller)),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('muestra el nombre del plan y el documento', (tester) async {
      await pumpDetail(tester);

      expect(find.text('Premium'), findsOneWidget);
      expect(find.textContaining('Plan n.º'), findsNothing);
      expect(find.text('Cédula de ciudadanía'), findsOneWidget);
      expect(find.text('1020304050'), findsOneWidget);
      // Jurídica: el documento es del representante legal.
      expect(
        find.text('Tipo de documento (representante legal)'),
        findsOneWidget,
      );
    });

    testWidgets('un plan que ya no existe no muestra su número', (
      tester,
    ) async {
      controller = AdminAccessController(
        repository: repository,
        loadPlans: () async => const [
          SubscriptionPlanOption(id: 1, name: 'Básico'),
        ],
      );
      await pumpDetail(tester);

      expect(find.text('Plan no disponible'), findsOneWidget);
      expect(find.textContaining('n.º'), findsNothing);
    });

    testWidgets('aprobar con error de red ofrece "Reintentar" y no cambia '
        'el estado hasta la confirmación', (tester) async {
      await pumpDetail(tester);
      await tester.tap(find.text('Aprobar'));
      await tester.pumpAndSettle();
      repository.failNext = const AdminAccessRepositoryException(
        AdminAccessFailureType.network,
        'No hay conexión. Revisa tu internet e intenta nuevamente.',
      );
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Aprobar'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SnackBarAction), findsOneWidget);
      expect(repository.approvedUids, isEmpty);
      expect(controller.pendingCount, 1);
      expect(find.byType(OwnerApprovalDetailPage), findsOneWidget);

      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(repository.approvedUids, ['o1']);
    });

    testWidgets('rechazar con error de red ofrece "Reintentar"', (
      tester,
    ) async {
      await pumpDetail(tester);
      await tester.tap(find.text('Rechazar'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Motivo del rechazo'),
        'El NIT no coincide con el RUT.',
      );
      repository.failNext = const AdminAccessRepositoryException(
        AdminAccessFailureType.network,
        'No hay conexión. Revisa tu internet e intenta nuevamente.',
      );
      await tester.tap(find.text('Confirmar rechazo'));
      await tester.pumpAndSettle();

      expect(repository.rejected, isEmpty);
      expect(controller.pendingCount, 1);
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(repository.rejected['o1'], 'El NIT no coincide con el RUT.');
    });
  });

  group('AG-13: administrador anonimizado', () {
    UserProfile admin(AccountStatus status, {String name = 'Admin Uno'}) =>
        UserProfile(
          uid: 'a1',
          fullName: name,
          email: 'a@machuco.com',
          phoneNumber: '+573000000000',
          role: RegisteredUserRole.admin,
          accountStatus: status,
        );

    test(
      'muestra "Administrador eliminado" si está anonimizado o no existe',
      () {
        expect(
          reviewerDisplayName(admin(AccountStatus.anonymized)),
          'Administrador eliminado',
        );
        expect(reviewerDisplayName(null), 'Administrador eliminado');
        expect(
          reviewerDisplayName(admin(AccountStatus.active, name: ' ')),
          'Administrador eliminado',
        );
        expect(reviewerDisplayName(admin(AccountStatus.active)), 'Admin Uno');
      },
    );
  });

  group('tarjeta de plan', () {
    Future<void> pumpPlans(
      WidgetTester tester,
      List<SubscriptionPlanOption> plans, {
      String? error,
      VoidCallback? onRetry,
    }) async {
      _bigView(tester);
      await tester.pumpWidget(
        testApp(
          Scaffold(
            body: SingleChildScrollView(
              child: PlanSelector(
                plans: plans,
                loading: false,
                errorMessage: error,
                selectedPlanId: null,
                onSelected: (_) {},
                onRetry: onRetry ?? () {},
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('muestra todos los campos con precio en COP', (tester) async {
      await pumpPlans(tester, const [
        SubscriptionPlanOption(
          id: 1,
          name: 'Premium',
          description: 'Para cadenas de moteles',
          price: 1249900,
          currency: 'COP',
          billingPeriod: 'monthly',
          features: ['Reportes', 'Soporte prioritario'],
          maxMotels: 5,
        ),
      ]);

      expect(find.text('Premium'), findsOneWidget);
      expect(find.text('Para cadenas de moteles'), findsOneWidget);
      expect(find.text(r'$1.249.900 COP / mensual'), findsOneWidget);
      expect(find.text('Hasta 5 moteles'), findsOneWidget);
      expect(find.text('Reportes'), findsOneWidget);
      expect(find.text('Soporte prioritario'), findsOneWidget);
    });

    testWidgets('oculta los campos null y traduce yearly', (tester) async {
      await pumpPlans(tester, const [
        SubscriptionPlanOption(
          id: 2,
          name: 'Básico',
          price: 99000,
          billingPeriod: 'yearly',
        ),
      ]);

      expect(find.text(r'$99.000 COP / anual'), findsOneWidget);
      expect(find.textContaining('Hasta'), findsNothing);
      expect(find.byIcon(Icons.check), findsNothing);
    });

    testWidgets('estado vacío y error ofrecen "Reintentar"', (tester) async {
      var retries = 0;
      await pumpPlans(tester, const [], onRetry: () => retries++);
      expect(
        find.textContaining('No hay planes disponibles por ahora'),
        findsOneWidget,
      );
      await tester.tap(find.text('Reintentar'));
      expect(retries, 1);

      await pumpPlans(tester, const [], error: 'No fue posible cargar.');
      await tester.pump();
      expect(find.text('No fue posible cargar.'), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);
    });
  });

  group('registro: planes y documentos no disponibles', () {
    late LoginController controller;

    Future<void> pumpForm(
      WidgetTester tester,
      FakeCatalogRepository catalog,
    ) async {
      _bigView(tester, height: 3600);
      controller = buildTestController(FakeAuthService(), catalog: catalog);
      await controller.loadCountryPhoneCodes();
      await tester.pumpWidget(
        testApp(
          Scaffold(
            body: SingleChildScrollView(
              child: RegisterForm(
                controller: controller,
                onSubmit: (_) async {},
                onLoginTap: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    bool submitEnabled(WidgetTester tester) =>
        tester
            .widget<AppButton>(find.widgetWithText(AppButton, 'Crear cuenta'))
            .onPressed !=
        null;

    testWidgets('sin planes: Propietario no puede crear la cuenta', (
      tester,
    ) async {
      await pumpForm(tester, FakeCatalogRepository(plans: const []));
      expect(submitEnabled(tester), isTrue); // Cliente no depende de planes.
      await tester.tap(find.text('Propietario'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('No hay planes disponibles por ahora'),
        findsOneWidget,
      );
      expect(submitEnabled(tester), isFalse);
    });

    testWidgets('error al cargar documentos: Reintentar y sin crear cuenta', (
      tester,
    ) async {
      final catalog = FakeCatalogRepository(failDocumentTypes: true);
      await pumpForm(tester, catalog);

      expect(
        find.byKey(const ValueKey('document-types-message')),
        findsOneWidget,
      );
      expect(find.text('Sin conexión'), findsOneWidget);
      expect(submitEnabled(tester), isFalse);

      catalog.failDocumentTypes = false;
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('document-types-message')),
        findsNothing,
      );
      expect(submitEnabled(tester), isTrue);
    });

    testWidgets('sin tipos de documento: estado vacío y sin crear cuenta', (
      tester,
    ) async {
      await pumpForm(tester, FakeCatalogRepository(documentTypes: const []));

      expect(
        find.text('No hay tipos de documento disponibles por ahora.'),
        findsOneWidget,
      );
      expect(submitEnabled(tester), isFalse);
    });

    testWidgets('Propietario jurídico aclara "documento del representante '
        'legal"; el NIT y la razón social no cambian', (tester) async {
      await pumpForm(tester, FakeCatalogRepository());
      await tester.tap(find.text('Propietario'));
      await tester.pumpAndSettle();
      expect(find.textContaining('representante legal'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('person-type-juridica')));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('documento del representante legal'),
        findsOneWidget,
      );
      expect(find.widgetWithText(TextFormField, 'NIT'), findsOneWidget);
      expect(
        find.widgetWithText(TextFormField, 'Razón social'),
        findsOneWidget,
      );
    });
  });
}
