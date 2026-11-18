import 'package:flutter_test/flutter_test.dart';
import 'package:machuco/controllers/auth/login_controller.dart';
import 'package:machuco/models/auth/document_type.dart';
import 'package:machuco/models/auth/registration_data.dart';
import 'package:machuco/models/owner_management/document_type.dart';
import 'package:machuco/service/auth/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../views/auth/auth_test_support.dart';

void main() {
  late FakeAuthService auth;
  late LoginController controller;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    auth = FakeAuthService();
    controller = buildTestController(auth);
    await controller.loadCountryPhoneCodes();
    await controller.loadDocumentTypes();
  });

  RegistrationData client(String documentNumber) => RegistrationData.client(
    firstNames: 'Ana María',
    lastNames: 'Pérez Gómez',
    phoneCountryCodeId: testColombia.id,
    phoneNumber: '3001234567',
    email: 'ana@example.com',
    password: 'Segura12345',
    documentType: DocumentType.citizenshipCard,
    documentNumber: documentNumber,
    birthDate: DateTime(1990, 3, 15),
  );

  test('carga los tipos y preselecciona la cédula de ciudadanía', () {
    expect(controller.documentTypes, isNotEmpty);
    expect(controller.defaultDocumentType?.code, 'CC');
    expect(controller.documentTypesError, isNull);
  });

  test('no envía el registro sin documento', () async {
    await expectLater(
      controller.registerAccount(client('')),
      throwsA(
        isA<AuthFailure>().having(
          (failure) => failure.type,
          'type',
          AuthFailureType.invalidInput,
        ),
      ),
    );
    expect(auth.registered, isNull);
  });

  test("no envía un documento con inyección SQL (' OR '1'='1' --)", () async {
    await expectLater(
      controller.registerAccount(client("' OR '1'='1' --")),
      throwsA(isA<AuthFailure>()),
    );
    expect(auth.registered, isNull);
  });

  test('envía el documento normalizado cuando es válido', () async {
    await controller.registerAccount(client('1.020.304.050'));
    expect(auth.registered?.documentNumber, '1020304050');
  });

  test('aplica el pattern del maestro y no el del enum', () async {
    final strict = FakeCatalogRepository(
      documentTypes: const [
        DocumentTypeOption(
          id: 1,
          code: 'CC',
          name: 'Cédula de ciudadanía',
          pattern: r'^\d{8}$',
          example: '10203040',
        ),
      ],
    );
    controller = buildTestController(auth, catalog: strict);
    await controller.loadCountryPhoneCodes();
    await controller.loadDocumentTypes();

    await expectLater(
      controller.registerAccount(client('1020304050')),
      throwsA(isA<AuthFailure>()),
    );
    await controller.registerAccount(client('10203040'));
    expect(auth.registered?.documentNumber, '10203040');
  });

  test('error del maestro: queda el mensaje y sin tipos para elegir', () async {
    controller = buildTestController(
      auth,
      catalog: FakeCatalogRepository(failDocumentTypes: true),
    );
    await controller.loadDocumentTypes();

    expect(controller.documentTypes, isEmpty);
    expect(controller.documentTypesError, 'Sin conexión');
    expect(controller.defaultDocumentType, isNull);
  });
}
