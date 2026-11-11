// Registro con correo desde el login: el celular se verifica por SMS antes de
// crear la cuenta. El servicio de SMS y el de autenticación son falsos.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:machuco/controllers/auth/login_controller.dart';
import 'package:machuco/core/design_system/design_system.dart';
import 'package:machuco/service/auth/auth_service.dart';
import 'package:machuco/views/login/login_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_test_support.dart';

void main() {
  late FakeAuthService auth;
  late FakePhoneVerificationService phone;
  late LoginController controller;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    auth = FakeAuthService();
    phone = FakePhoneVerificationService();
    controller = buildTestController(auth, phoneVerification: phone);
  });

  Finder field(String label) => find.widgetWithText(TextFormField, label);

  Future<void> fillClientAndSubmit(WidgetTester tester) async {
    tester.view.physicalSize = const Size(700, 3200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: LoginPage(controller: controller, initialTab: AuthTab.register),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(field('Nombres'), 'Ana María');
    await tester.enterText(field('Apellidos'), 'Pérez Gómez');
    await tester.enterText(field('Celular'), '300 123 4567');
    await tester.enterText(field('Fecha de nacimiento'), '15/03/1990');
    await tester.enterText(field('Correo electrónico'), 'ana@example.com');
    await tester.enterText(field('Contraseña'), 'Segura12345');
    await tester.enterText(field('Confirmar contraseña'), 'Segura12345');
    await tester.tap(find.widgetWithText(AppButton, 'Crear cuenta'));
    await tester.pumpAndSettle();
  }

  Future<void> typeCodeAndConfirm(WidgetTester tester, String code) async {
    await tester.enterText(field('Código de verificación'), code);
    await tester.tap(find.text('Verificar y crear cuenta'));
    await tester.pumpAndSettle();
  }

  testWidgets('"Crear cuenta" envía el SMS al celular con indicativo y aún '
      'no crea la cuenta', (tester) async {
    await fillClientAndSubmit(tester);

    expect(find.text('Verifica tu celular'), findsOneWidget);
    expect(phone.sent, [(phone: '+573001234567', isResend: false)]);
    expect(auth.registered, isNull);
  });

  testWidgets('con el código correcto crea la cuenta con la prueba del '
      'celular', (tester) async {
    await fillClientAndSubmit(tester);

    await typeCodeAndConfirm(tester, '123456');

    final data = auth.registered;
    expect(data, isNotNull);
    expect(data!.phoneNumber, '+573001234567');
    expect(data.email, 'ana@example.com');
    expect(data.phoneProof?.phoneNumber, '+573001234567');
    expect(find.text('Verifica tu celular'), findsNothing);
    expect(
      find.text('Cuenta creada correctamente. Ahora inicia sesión.'),
      findsOneWidget,
    );
  });

  testWidgets('código incorrecto: la cuenta no se crea y se puede reintentar', (
    tester,
  ) async {
    auth.registerFailure = const AuthFailure(
      AuthFailureType.invalidVerificationCode,
      'El código no es correcto. Revísalo e intenta de nuevo.',
    );
    await fillClientAndSubmit(tester);

    await typeCodeAndConfirm(tester, '000000');

    expect(find.textContaining('El código no es correcto'), findsOneWidget);
    expect(find.text('Verifica tu celular'), findsOneWidget);
    expect(auth.registered, isNull);

    auth.registerFailure = null;
    await typeCodeAndConfirm(tester, '123456');

    expect(auth.registered, isNotNull);
    expect(find.text('Verifica tu celular'), findsNothing);
  });

  testWidgets('celular de otra cuenta: lo informa y no crea la cuenta', (
    tester,
  ) async {
    auth.registerFailure = const AuthFailure(
      AuthFailureType.phoneAlreadyInUse,
      'Este celular ya está asociado a otra cuenta.',
    );
    await fillClientAndSubmit(tester);

    await typeCodeAndConfirm(tester, '123456');

    expect(
      find.text('Este celular ya está asociado a otra cuenta.'),
      findsOneWidget,
    );
    expect(auth.registered, isNull);
  });

  testWidgets('cancelar la hoja no crea la cuenta y conserva el formulario', (
    tester,
  ) async {
    await fillClientAndSubmit(tester);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(auth.registered, isNull);
    expect(find.text('Verifica tu celular'), findsNothing);
    expect(field('Nombres'), findsOneWidget);
    expect(find.text('Ana María'), findsOneWidget);
  });

  testWidgets('un celular inválido no gasta un SMS', (tester) async {
    tester.view.physicalSize = const Size(700, 3200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: LoginPage(controller: controller, initialTab: AuthTab.register),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(field('Nombres'), 'Ana María');
    await tester.enterText(field('Apellidos'), 'Pérez Gómez');
    await tester.enterText(field('Celular'), '123');
    await tester.enterText(field('Fecha de nacimiento'), '15/03/1990');
    await tester.enterText(field('Correo electrónico'), 'ana@example.com');
    await tester.enterText(field('Contraseña'), 'Segura12345');
    await tester.enterText(field('Confirmar contraseña'), 'Segura12345');
    await tester.tap(find.widgetWithText(AppButton, 'Crear cuenta'));
    await tester.pumpAndSettle();

    expect(phone.sent, isEmpty);
    expect(find.text('Verifica tu celular'), findsNothing);
  });
}
