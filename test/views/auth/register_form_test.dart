import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:machuco/controllers/auth/login_controller.dart';
import 'package:machuco/controllers/auth/validators/auth_validators.dart';
import 'package:machuco/core/design_system/design_system.dart';
import 'package:machuco/models/auth/person_type.dart';
import 'package:machuco/models/auth/registration_data.dart';
import 'package:machuco/models/owner_management/document_type.dart';
import 'package:machuco/views/register/register_form.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_test_support.dart';

void main() {
  late FakeAuthService auth;
  late LoginController controller;
  RegistrationData? submitted;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    auth = FakeAuthService();
    submitted = null;
  });

  Future<void> pumpForm(
    WidgetTester tester, {
    FakeCatalogRepository? catalog,
  }) async {
    tester.view.physicalSize = const Size(412, 3200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    controller = buildTestController(auth, catalog: catalog);
    await controller.loadCountryPhoneCodes();
    await tester.pumpWidget(
      testApp(
        Scaffold(
          body: SingleChildScrollView(
            child: RegisterForm(
              controller: controller,
              onSubmit: (data) async => submitted = data,
              onLoginTap: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder field(String label) => find.widgetWithText(TextFormField, label);

  Future<void> selectOwner(WidgetTester tester) async {
    await tester.tap(find.text('Propietario'));
    await tester.pumpAndSettle();
  }

  /// Documento de identidad (decisión 2026-11-17): CC, CE y pasaporte, con
  /// selector de tipo (hoja inferior) y número en una sola fila.
  Future<void> expectIdentityDocument(WidgetTester tester) async {
    expect(find.byKey(const ValueKey('document-field')), findsOneWidget);
    expect(find.text('Documento de identidad'), findsOneWidget);
    expect(find.byKey(const ValueKey('document-type-button')), findsOneWidget);
    expect(field('Número de documento'), findsOneWidget);
    // El hint es el ejemplo del tipo elegido (CC por defecto).
    expect(find.text('1020304050'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('document-type-button')));
    await tester.pumpAndSettle();
    expect(find.text('Cédula de ciudadanía'), findsOneWidget);
    expect(find.text('Cédula de extranjería'), findsOneWidget);
    expect(find.text('Pasaporte'), findsOneWidget);
    // Ni tarjeta de identidad (menores) ni NIT como documento.
    expect(find.text('Tarjeta de identidad'), findsNothing);
    expect(find.text('Número de identificación tributaria'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('document-type-option-CC')));
    await tester.pumpAndSettle();
  }

  Future<void> pickPassport(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('document-type-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('document-type-option-PAS')));
    await tester.pumpAndSettle();
  }

  testWidgets('cliente: muestra sus campos y el documento de identidad', (
    tester,
  ) async {
    await pumpForm(tester);

    expect(field('Nombres'), findsOneWidget);
    expect(field('Apellidos'), findsOneWidget);
    expect(field('Fecha de nacimiento'), findsOneWidget);
    expect(field('NIT'), findsNothing);
    expect(find.text('Plan de suscripción'), findsNothing);
    await expectIdentityDocument(tester);
  });

  testWidgets('propietario: muestra NIT y planes, sin fecha de nacimiento', (
    tester,
  ) async {
    await pumpForm(tester);
    await selectOwner(tester);

    expect(field('NIT'), findsOneWidget);
    expect(find.text('Persona natural'), findsOneWidget);
    expect(find.text('Persona jurídica'), findsOneWidget);
    expect(find.text('Básico'), findsOneWidget);
    expect(find.text('Premium'), findsOneWidget);
    expect(field('Fecha de nacimiento'), findsNothing);
    // El documento de identidad va aparte del NIT.
    await expectIdentityDocument(tester);
  });

  testWidgets('la razón social aparece solo en persona jurídica y el NIT se '
      'conserva al volver a natural', (tester) async {
    await pumpForm(tester);
    await selectOwner(tester);

    expect(field('Razón social'), findsNothing);

    await tester.tap(find.text('Persona jurídica'));
    await tester.pumpAndSettle();
    expect(field('Razón social'), findsOneWidget);

    await tester.enterText(field('NIT'), '900123456-8');
    await tester.enterText(field('Razón social'), 'Moteles del Sur SAS');

    await tester.tap(find.text('Persona natural'));
    await tester.pumpAndSettle();
    expect(field('Razón social'), findsNothing);
    expect(find.text('900123456-8'), findsOneWidget);

    await tester.tap(find.text('Persona jurídica'));
    await tester.pumpAndSettle();
    expect(find.text('Moteles del Sur SAS'), findsNothing);
  });

  testWidgets('cambiar de rol conserva los datos comunes', (tester) async {
    await pumpForm(tester);
    await tester.enterText(field('Nombres'), 'Ana María');
    await tester.enterText(field('Correo electrónico'), 'ana@example.com');

    await selectOwner(tester);
    await tester.tap(find.text('Cliente'));
    await tester.pumpAndSettle();

    expect(find.text('Ana María'), findsOneWidget);
    expect(find.text('ana@example.com'), findsOneWidget);
  });

  testWidgets('los términos abren y cierran conservando los datos', (
    tester,
  ) async {
    await pumpForm(tester);
    await tester.enterText(field('Nombres'), 'Ana María');

    await tester.tap(find.text('Términos y condiciones'));
    await tester.pumpAndSettle();
    expect(
      find.text('Contenido de términos y condiciones pendiente'),
      findsOneWidget,
    );

    await tester.tap(find.text('Cerrar'));
    await tester.pumpAndSettle();
    expect(
      find.text('Contenido de términos y condiciones pendiente'),
      findsNothing,
    );
    expect(find.text('Ana María'), findsOneWidget);
  });

  testWidgets('propietario sin planes: "Crear cuenta" queda deshabilitado', (
    tester,
  ) async {
    await pumpForm(tester, catalog: FakeCatalogRepository(plans: const []));
    await selectOwner(tester);

    expect(find.textContaining('No hay planes disponibles'), findsOneWidget);
    final button = tester.widget<AppButton>(
      find.widgetWithText(AppButton, 'Crear cuenta'),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('error al cargar planes ofrece Reintentar', (tester) async {
    final catalog = FakeCatalogRepository(failPlans: true);
    await pumpForm(tester, catalog: catalog);
    await selectOwner(tester);

    expect(find.text('Sin conexión'), findsOneWidget);
    catalog.failPlans = false;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(find.text('Básico'), findsOneWidget);
  });

  testWidgets('envía los datos del cliente validados', (tester) async {
    await pumpForm(tester);
    await tester.enterText(field('Nombres'), 'Ana María');
    await tester.enterText(field('Apellidos'), 'Pérez Gómez');
    await tester.enterText(field('Número de documento'), '1.020.304.050');
    await tester.enterText(field('Celular'), '3001234567');
    await tester.enterText(field('Fecha de nacimiento'), '15/03/1990');
    await tester.enterText(field('Correo electrónico'), 'ana@example.com');
    await tester.enterText(field('Contraseña'), 'Segura12345');
    await tester.enterText(field('Confirmar contraseña'), 'Segura12345');

    await tester.tap(find.widgetWithText(AppButton, 'Crear cuenta'));
    await tester.pumpAndSettle();

    expect(submitted, isNotNull);
    expect(submitted!.firstNames, 'Ana María');
    expect(submitted!.phoneNumber, '3001234567');
    expect(submitted!.birthDate, DateTime(1990, 3, 15));
    expect(submitted!.documentType, DocumentType.citizenshipCard);
    // La vista entrega lo escrito; el controller lo normaliza.
    expect(submitted!.documentNumber, '1.020.304.050');
  });

  testWidgets('sin documento o con un número inválido no se envía', (
    tester,
  ) async {
    await pumpForm(tester);
    await tester.enterText(field('Nombres'), 'Ana María');
    await tester.enterText(field('Apellidos'), 'Pérez Gómez');
    await tester.enterText(field('Celular'), '3001234567');
    await tester.enterText(field('Fecha de nacimiento'), '15/03/1990');
    await tester.enterText(field('Correo electrónico'), 'ana@example.com');
    await tester.enterText(field('Contraseña'), 'Segura12345');
    await tester.enterText(field('Confirmar contraseña'), 'Segura12345');

    await tester.tap(find.widgetWithText(AppButton, 'Crear cuenta'));
    await tester.pumpAndSettle();
    expect(submitted, isNull);
    expect(find.text('Ingresa tu número de documento.'), findsOneWidget);

    // Letras en una cédula: inválido para CC, válido como pasaporte.
    await tester.enterText(field('Número de documento'), 'AV123456');
    await tester.tap(find.widgetWithText(AppButton, 'Crear cuenta'));
    await tester.pumpAndSettle();
    expect(submitted, isNull);
    expect(
      find.textContaining('Número no válido. Ejemplo: 1020304050.'),
      findsOneWidget,
    );

    await pickPassport(tester);
    await tester.tap(find.widgetWithText(AppButton, 'Crear cuenta'));
    await tester.pumpAndSettle();
    expect(submitted?.documentType, DocumentType.passport);
    expect(submitted?.documentNumber, 'AV123456');
  });

  testWidgets('envía los datos del propietario con NIT válido y plan', (
    tester,
  ) async {
    await pumpForm(tester);
    await selectOwner(tester);
    await tester.tap(find.text('Persona jurídica'));
    await tester.pumpAndSettle();
    await tester.enterText(field('Nombres'), 'Ana María');
    await tester.enterText(field('Apellidos'), 'Pérez Gómez');
    await tester.enterText(field('Celular'), '3001234567');
    await tester.enterText(field('Número de documento'), '43123456');
    await tester.enterText(field('NIT'), '900123456-8');
    await tester.enterText(field('Razón social'), 'Moteles del Sur SAS');
    await tester.enterText(field('Correo electrónico'), 'ana@example.com');
    await tester.enterText(field('Contraseña'), 'Segura12345');
    await tester.enterText(field('Confirmar contraseña'), 'Segura12345');

    // Sin plan seleccionado no se envía.
    await tester.tap(find.widgetWithText(AppButton, 'Crear cuenta'));
    await tester.pumpAndSettle();
    expect(submitted, isNull);
    expect(find.text('Selecciona un plan.'), findsOneWidget);

    await tester.tap(find.text('Premium'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(AppButton, 'Crear cuenta'));
    await tester.pumpAndSettle();

    expect(submitted?.personType, PersonType.juridica);
    expect(submitted?.nit, '900123456-8');
    expect(submitted?.documentNumber, '43123456');
    expect(submitted?.planId, 2);
  });

  testWidgets('muestra el error de un formato inválido bajo el campo', (
    tester,
  ) async {
    await pumpForm(tester);
    await tester.enterText(field('Correo electrónico'), 'no-es-correo');
    await tester.pump();

    expect(find.text(AuthValidators.email('no-es-correo')!), findsOneWidget);
  });
}
