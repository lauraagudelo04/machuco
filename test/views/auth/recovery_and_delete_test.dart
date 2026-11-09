import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:machuco/controllers/auth/login_controller.dart';
import 'package:machuco/core/design_system/design_system.dart';
import 'package:machuco/service/auth/auth_service.dart';
import 'package:machuco/models/auth/auth_provider_kind.dart';
import 'package:machuco/widgets/auth/social_auth_buttons.dart';
import 'package:machuco/widgets/auth/delete_account_sheet.dart';
import 'package:machuco/widgets/auth/forgot_password_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_test_support.dart';

void main() {
  late FakeAuthService auth;
  late LoginController controller;
  bool? deleteResult;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    auth = FakeAuthService();
    controller = buildTestController(auth);
    deleteResult = null;
  });

  Future<void> openFrom(
    WidgetTester tester,
    Future<void> Function(BuildContext context) open,
  ) async {
    tester.view.physicalSize = const Size(700, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      testApp(
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => open(context),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
  }

  AppButton button(WidgetTester tester, String label) =>
      tester.widget<AppButton>(find.widgetWithText(AppButton, label));

  group('recuperación de contraseña', () {
    testWidgets('muestra el mensaje neutro y la cuenta regresiva', (
      tester,
    ) async {
      await openFrom(
        tester,
        (context) => showForgotPasswordSheet(
          context,
          controller: controller,
          initialEmail: 'ana@example.com',
        ),
      );

      expect(find.text('ana@example.com'), findsOneWidget);
      await tester.tap(find.text('Enviar instrucciones'));
      await tester.pump();
      await tester.pump();

      expect(auth.resetEmails, ['ana@example.com']);
      expect(find.text(passwordResetNeutralMessage), findsOneWidget);
      expect(find.text('Reenviar en 60s'), findsOneWidget);
      expect(button(tester, 'Reenviar en 60s').onPressed, isNull);

      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Reenviar en 59s'), findsOneWidget);

      // Libera el temporizador del enfriamiento antes de terminar.
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    });

    testWidgets('valida el correo y muestra el error de demasiados intentos', (
      tester,
    ) async {
      await openFrom(
        tester,
        (context) => showForgotPasswordSheet(context, controller: controller),
      );

      await tester.tap(find.text('Enviar instrucciones'));
      await tester.pump();
      expect(auth.resetEmails, isEmpty);

      auth.resetFailure = const AuthFailure(
        AuthFailureType.tooManyRequests,
        'Demasiados intentos. Espera un momento.',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Correo electrónico'),
        'ana@example.com',
      );
      await tester.tap(find.text('Enviar instrucciones'));
      await tester.pump();
      await tester.pump();

      expect(
        find.text('Demasiados intentos. Espera un momento.'),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    });
  });

  group('eliminar cuenta', () {
    Future<void> openDelete(WidgetTester tester) => openFrom(
      tester,
      (context) async => deleteResult = await showDeleteAccountSheet(
        context,
        controller: controller,
      ),
    );

    testWidgets('el botón se habilita solo con la contraseña y ELIMINAR', (
      tester,
    ) async {
      await openDelete(tester);
      Finder input(String label) => find.widgetWithText(TextFormField, label);

      expect(find.text('Eliminar cuenta'), findsOneWidget);
      expect(button(tester, 'Eliminar definitivamente').onPressed, isNull);

      await tester.enterText(input('Contraseña actual'), 'Segura12345');
      await tester.pump();
      expect(button(tester, 'Eliminar definitivamente').onPressed, isNull);

      await tester.enterText(
        input('Escribe ELIMINAR para confirmar'),
        'eliminar',
      );
      await tester.pump();
      expect(button(tester, 'Eliminar definitivamente').onPressed, isNull);

      await tester.enterText(
        input('Escribe ELIMINAR para confirmar'),
        'ELIMINAR',
      );
      await tester.pump();
      expect(button(tester, 'Eliminar definitivamente').onPressed, isNotNull);

      await tester.tap(find.text('Eliminar definitivamente'));
      await tester.pumpAndSettle();
      expect(auth.deletedWithPasswords, ['Segura12345']);
      expect(deleteResult, isTrue);
    });

    testWidgets('Cancelar cierra sin eliminar', (tester) async {
      await openDelete(tester);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(deleteResult, isFalse);
      expect(auth.deletedWithPasswords, isEmpty);
    });
  });

  group('botones sociales', () {
    testWidgets('[SOC-UI-01] habilitados sin "Próximamente"; el toque llama '
        'al proveedor', (tester) async {
      final selected = <AuthProviderKind>[];
      await tester.pumpWidget(
        testApp(Scaffold(body: SocialAuthButtons(onSelected: selected.add))),
      );

      expect(find.text('Próximamente'), findsNothing);
      await tester.tap(find.text('Continuar con GitHub'));
      expect(selected, [AuthProviderKind.github]);
    });

    testWidgets('[SOC-UI-02] en curso: carga en el elegido y ambos '
        'bloqueados', (tester) async {
      await tester.pumpWidget(
        testApp(
          Scaffold(
            body: SocialAuthButtons(
              onSelected: (_) {},
              busyProvider: AuthProviderKind.google,
            ),
          ),
        ),
      );

      final google = tester.widget<AppButton>(
        find.byKey(const ValueKey('social-google')),
      );
      expect(google.loading, isTrue);
      expect(google.onPressed, isNull);
      expect(button(tester, 'Continuar con GitHub').onPressed, isNull);
    });

    testWidgets('sin Firebase disponible se deshabilitan con explicación', (
      tester,
    ) async {
      await tester.pumpWidget(
        testApp(const Scaffold(body: SocialAuthButtons(onSelected: null))),
      );

      expect(find.textContaining('no está disponible'), findsOneWidget);
      expect(button(tester, 'Continuar con Google').onPressed, isNull);
    });
  });
}
