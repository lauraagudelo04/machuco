import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:machuco/models/auth/phone_verification.dart';
import 'package:machuco/service/auth/auth_service.dart';
import 'package:machuco/widgets/auth/phone_verification_sheet.dart';

import '../../views/auth/auth_test_support.dart';

const _phone = '+573001234567';

void main() {
  late FakePhoneVerificationService service;
  late List<PhoneVerificationProof> verified;
  late AuthFailure? verifyFailure;
  bool? result;

  setUp(() {
    service = FakePhoneVerificationService();
    verified = [];
    verifyFailure = null;
    result = null;
  });

  Future<void> openSheet(WidgetTester tester) async {
    await tester.pumpWidget(
      testApp(
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showPhoneVerificationSheet(
                  context,
                  service: service,
                  phoneNumber: _phone,
                  onVerified: (proof) async {
                    final failure = verifyFailure;
                    if (failure != null) throw failure;
                    verified.add(proof);
                  },
                );
              },
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
  }

  Finder codeField() =>
      find.widgetWithText(TextFormField, 'Código de verificación');

  testWidgets('envía el SMS al abrir y muestra el número', (tester) async {
    await openSheet(tester);

    expect(service.sent, [(phone: _phone, isResend: false)]);
    expect(find.textContaining(_phone), findsOneWidget);
    expect(codeField(), findsOneWidget);
  });

  testWidgets('con un código válido llama a onVerified y se cierra', (
    tester,
  ) async {
    await openSheet(tester);

    await tester.enterText(codeField(), '123456');
    await tester.tap(find.text('Verificar y continuar'));
    await tester.pumpAndSettle();

    expect(verified, hasLength(1));
    expect((verified.single as FakePhoneProof).smsCode, '123456');
    expect(verified.single.phoneNumber, _phone);
    expect(result, isTrue);
    expect(find.text('Verifica tu celular'), findsNothing);
  });

  testWidgets('código vacío o incompleto no llama a onVerified', (
    tester,
  ) async {
    await openSheet(tester);

    await tester.tap(find.text('Verificar y continuar'));
    await tester.pumpAndSettle();
    expect(
      find.text('Escribe el código que recibiste por SMS.'),
      findsOneWidget,
    );

    await tester.enterText(codeField(), '123');
    await tester.tap(find.text('Verificar y continuar'));
    await tester.pumpAndSettle();
    expect(find.text('El código tiene 6 dígitos.'), findsOneWidget);
    expect(verified, isEmpty);
  });

  testWidgets('solo acepta dígitos y como máximo 6', (tester) async {
    await openSheet(tester);

    await tester.enterText(codeField(), '12ab3456789');

    final field = tester.widget<TextFormField>(codeField());
    expect(field.controller?.text, '123456');
  });

  testWidgets('código incorrecto: muestra el error y deja reintentar', (
    tester,
  ) async {
    verifyFailure = const AuthFailure(
      AuthFailureType.invalidVerificationCode,
      'El código no es correcto. Revísalo e intenta de nuevo.',
    );
    await openSheet(tester);

    await tester.enterText(codeField(), '000000');
    await tester.tap(find.text('Verificar y continuar'));
    await tester.pumpAndSettle();

    expect(find.textContaining('El código no es correcto'), findsOneWidget);
    expect(find.text('Verifica tu celular'), findsOneWidget);
    expect(result, isNull);

    verifyFailure = null;
    await tester.enterText(codeField(), '123456');
    await tester.tap(find.text('Verificar y continuar'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });

  testWidgets('reenviar queda bloqueado 60 s y luego reenvía con el token', (
    tester,
  ) async {
    await openSheet(tester);

    final blocked = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Reenviar código en 60s'),
    );
    expect(blocked.onPressed, isNull);

    await tester.pump(const Duration(seconds: 60));
    expect(find.text('Reenviar código'), findsOneWidget);

    await tester.tap(find.text('Reenviar código'));
    await tester.pump();
    await tester.pump();

    expect(service.sent.last, (phone: _phone, isResend: true));
    expect(find.text('Reenviar código en 60s'), findsOneWidget);
  });

  testWidgets('si no se pudo enviar el SMS ofrece reintentar', (tester) async {
    service.sendFailure = const AuthFailure(
      AuthFailureType.network,
      'No hay conexión. Revisa tu internet e intenta nuevamente.',
    );
    await openSheet(tester);

    expect(find.textContaining('No hay conexión'), findsOneWidget);
    expect(codeField(), findsNothing);

    service.sendFailure = null;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();

    expect(codeField(), findsOneWidget);
  });

  testWidgets('verificación instantánea: continúa sin pedir el código', (
    tester,
  ) async {
    service.autoVerifiedProof = const FakePhoneProof(_phone, 'auto');
    await openSheet(tester);

    expect(verified, hasLength(1));
    expect(result, isTrue);
  });

  testWidgets('Cancelar cierra la hoja sin verificar', (tester) async {
    await openSheet(tester);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(result, isFalse);
    expect(verified, isEmpty);
  });
}
