import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:machuco/controllers/auth/login_controller.dart';
import 'package:machuco/core/design_system/design_system.dart';
import 'package:machuco/routes/routes.dart';
import 'package:machuco/service/auth/auth_service.dart';
import 'package:machuco/views/login/login_page.dart';
import 'package:machuco/widgets/auth/forgot_password_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_test_support.dart';

void main() {
  late FakeAuthService auth;
  late LoginController controller;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    auth = FakeAuthService();
    controller = buildTestController(auth);
  });

  Future<void> pumpLogin(
    WidgetTester tester, {
    AuthTab tab = AuthTab.login,
  }) async {
    tester.view.physicalSize = const Size(700, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: LoginPage(controller: controller, initialTab: tab),
        onGenerateRoute: (settings) => MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => Scaffold(body: Text('ruta:${settings.name}')),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder field(String label) => find.widgetWithText(TextFormField, label);

  Future<void> fillClientAndSubmit(WidgetTester tester) async {
    await tester.enterText(field('Nombres'), 'Ana María');
    await tester.enterText(field('Apellidos'), 'Pérez Gómez');
    await tester.enterText(field('Número de documento'), '1020304050');
    await tester.enterText(field('Celular'), '3001234567');
    await tester.enterText(field('Fecha de nacimiento'), '15/03/1990');
    await tester.enterText(field('Correo electrónico'), 'ana@example.com');
    await tester.enterText(field('Contraseña'), 'Segura12345');
    await tester.enterText(field('Confirmar contraseña'), 'Segura12345');
    await tester.tap(find.widgetWithText(AppButton, 'Crear cuenta'));
    await tester.pumpAndSettle();
  }

  testWidgets('RC-03: el login no muestra banner de desarrollo ni usuarios '
      'de prueba', (tester) async {
    await pumpLogin(tester);

    expect(find.textContaining('desarrollo', findRichText: true), findsNothing);
    expect(find.textContaining('de prueba', findRichText: true), findsNothing);
    expect(find.textContaining('Usuarios', findRichText: true), findsNothing);
    expect(field('Correo electrónico'), findsOneWidget);
  });

  testWidgets('el cliente recién registrado va a su ruta, no al login', (
    tester,
  ) async {
    await pumpLogin(tester, tab: AuthTab.register);
    await fillClientAndSubmit(tester);

    expect(auth.registered?.email, 'ana@example.com');
    expect(find.text('ruta:${AppRoutes.clientMotels}'), findsOneWidget);
    expect(find.byType(LoginPage), findsNothing);
  });

  group('correo ya registrado', () {
    setUp(() {
      auth.registerFailure = const AuthFailure(
        AuthFailureType.emailAlreadyExists,
        'Este correo ya está registrado.',
      );
    });

    testWidgets('ofrece "Iniciar sesión" con el correo puesto', (tester) async {
      await pumpLogin(tester, tab: AuthTab.register);
      await fillClientAndSubmit(tester);

      expect(find.byKey(const ValueKey('email-in-use-notice')), findsOneWidget);
      expect(find.text('¿Olvidaste tu contraseña?'), findsWidgets);

      await tester.tap(find.byKey(const ValueKey('email-in-use-login')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('email-in-use-notice')), findsNothing);
      final email = tester.widget<TextFormField>(field('Correo electrónico'));
      expect(email.controller?.text, 'ana@example.com');
      expect(find.byKey(const ValueKey('register-tab')), findsNothing);
    });

    testWidgets('PR-09: "¿Olvidaste tu contraseña?" abre el sheet con el '
        'correo y tras enviar bloquea con cuenta regresiva', (tester) async {
      await pumpLogin(tester, tab: AuthTab.register);
      await fillClientAndSubmit(tester);

      await tester.tap(find.byKey(const ValueKey('email-in-use-forgot')));
      await tester.pumpAndSettle();

      expect(find.byType(ForgotPasswordSheet), findsOneWidget);
      expect(find.text('ana@example.com'), findsWidgets);

      await tester.tap(find.text('Enviar instrucciones'));
      await tester.pump();
      await tester.pump();

      expect(auth.resetEmails, ['ana@example.com']);
      final resend = tester.widget<AppButton>(
        find.widgetWithText(AppButton, 'Reenviar en 60s'),
      );
      expect(resend.onPressed, isNull);

      // Libera el temporizador del enfriamiento antes de terminar.
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    });
  });
}
