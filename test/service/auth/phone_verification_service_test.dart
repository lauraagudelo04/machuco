import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:machuco/models/auth/phone_verification.dart';
import 'package:machuco/service/auth/auth_service.dart';
import 'package:machuco/service/auth/phone_verification_service.dart';

import 'phone_proof_support.dart';

const _phone = '+573001234567';

typedef _Script =
    FutureOr<void> Function({
      required PhoneVerificationCompleted completed,
      required PhoneVerificationFailed failed,
      required PhoneCodeSent sent,
    });

void main() {
  late _FakeAuth auth;
  late FirebasePhoneVerificationService service;

  setUp(() {
    auth = _FakeAuth();
    service = FirebasePhoneVerificationService(
      firebaseAuth: auth,
      responseTimeout: const Duration(milliseconds: 50),
    );
  });

  Matcher failureOf(AuthFailureType type) => throwsA(
    isA<AuthFailure>().having((failure) => failure.type, 'type', type),
  );

  group('sendCode', () {
    test(
      'devuelve la sesión de verificación cuando Firebase envía el SMS',
      () async {
        auth.script = ({required completed, required failed, required sent}) =>
            sent('verification-id', 42);

        final request = await service.sendCode(phoneNumber: _phone);

        expect(auth.lastPhone, _phone);
        expect(request.phoneNumber, _phone);
        expect(request.verificationId, 'verification-id');
        expect(request.resendToken, 42);
        expect(request.autoVerifiedProof, isNull);
      },
    );

    test('al reenviar usa el token de la solicitud anterior', () async {
      auth.script = ({required completed, required failed, required sent}) =>
          sent('verification-id', 42);
      final first = await service.sendCode(phoneNumber: _phone);

      await service.sendCode(phoneNumber: _phone, resendFrom: first);

      expect(auth.lastResendToken, 42);
    });

    test(
      'la verificación instantánea entrega la prueba sin pedir código',
      () async {
        auth.script = ({required completed, required failed, required sent}) =>
            completed(
              PhoneAuthProvider.credential(
                verificationId: 'verification-id',
                smsCode: '123456',
              ),
            );

        final request = await service.sendCode(phoneNumber: _phone);

        expect(
          request.autoVerifiedProof,
          isA<FirebasePhoneVerificationProof>(),
        );
        expect(request.autoVerifiedProof?.phoneNumber, _phone);
      },
    );

    test('traduce el error de Firebase a un AuthFailure', () async {
      auth.script = ({required completed, required failed, required sent}) =>
          failed(FirebaseAuthException(code: 'invalid-phone-number'));

      await expectLater(
        service.sendCode(phoneNumber: _phone),
        failureOf(AuthFailureType.invalidInput),
      );
    });

    test('traduce el error lanzado por verifyPhoneNumber', () async {
      auth.throwOnVerify = FirebaseAuthException(code: 'too-many-requests');

      await expectLater(
        service.sendCode(phoneNumber: _phone),
        failureOf(AuthFailureType.tooManyRequests),
      );
    });

    test('plataforma sin soporte: avisa que no está disponible', () async {
      auth.unsupported = true;

      await expectLater(
        service.sendCode(phoneNumber: _phone),
        failureOf(AuthFailureType.providerMisconfigured),
      );
    });

    test('sin respuesta de Firebase termina con error de conexión', () async {
      auth.script = ({required completed, required failed, required sent}) {};

      await expectLater(
        service.sendCode(phoneNumber: _phone),
        failureOf(AuthFailureType.network),
      );
    });
  });

  group('buildProof', () {
    const request = PhoneCodeRequest(
      phoneNumber: _phone,
      verificationId: 'verification-id',
    );

    test('con un código de 6 dígitos devuelve la prueba del número', () {
      final proof = service.buildProof(request: request, smsCode: ' 123456 ');

      expect(proof, isA<FirebasePhoneVerificationProof>());
      expect(proof.phoneNumber, _phone);
      final credential = (proof as FirebasePhoneVerificationProof).credential;
      expect(credential.verificationId, 'verification-id');
      expect(credential.smsCode, '123456');
    });

    for (final code in ['', '12345', '1234567', '12a456', "1' OR '1'='1"]) {
      test('rechaza "$code" sin llamar a Firebase', () {
        expect(
          () => service.buildProof(request: request, smsCode: code),
          throwsA(
            isA<AuthFailure>().having(
              (failure) => failure.type,
              'type',
              AuthFailureType.invalidVerificationCode,
            ),
          ),
        );
      });
    }
  });

  group('requireVerifiedPhoneProof', () {
    test('acepta la prueba del mismo número', () {
      final proof = phoneProof(_phone);
      expect(requireVerifiedPhoneProof(proof, phoneNumber: _phone), proof);
    });

    test('rechaza la ausencia de prueba y la de otro número', () {
      for (final proof in [null, phoneProof('+573009998877')]) {
        expect(
          () => requireVerifiedPhoneProof(proof, phoneNumber: _phone),
          throwsA(
            isA<AuthFailure>().having(
              (failure) => failure.type,
              'type',
              AuthFailureType.phoneNotVerified,
            ),
          ),
        );
      }
    });

    test('rechaza una prueba que no emitió Firebase', () {
      expect(
        () => requireVerifiedPhoneProof(_ForeignProof(), phoneNumber: _phone),
        throwsA(isA<AuthFailure>()),
      );
    });
  });

  group('phoneAuthFailureFor', () {
    const expected = <String, AuthFailureType>{
      'invalid-phone-number': AuthFailureType.invalidInput,
      'missing-phone-number': AuthFailureType.invalidInput,
      'invalid-verification-code': AuthFailureType.invalidVerificationCode,
      'invalid-verification-id': AuthFailureType.verificationExpired,
      'session-expired': AuthFailureType.verificationExpired,
      'credential-already-in-use': AuthFailureType.phoneAlreadyInUse,
      'too-many-requests': AuthFailureType.tooManyRequests,
      'quota-exceeded': AuthFailureType.tooManyRequests,
      'network-request-failed': AuthFailureType.network,
      'operation-not-allowed': AuthFailureType.providerMisconfigured,
      'captcha-check-failed': AuthFailureType.providerMisconfigured,
      'algo-nuevo': AuthFailureType.unknown,
    };
    expected.forEach((code, type) {
      test('$code -> $type', () {
        expect(
          phoneAuthFailureFor(FirebaseAuthException(code: code)).type,
          type,
        );
      });
    });

    test('no filtra el mensaje crudo de Firebase', () {
      final failure = phoneAuthFailureFor(
        FirebaseAuthException(code: 'algo-nuevo', message: 'detalle interno'),
      );
      expect(failure.message, isNot(contains('detalle interno')));
    });
  });
}

final class _ForeignProof implements PhoneVerificationProof {
  @override
  String get phoneNumber => _phone;
}

final class _FakeAuth implements FirebaseAuth {
  _Script? script;
  FirebaseAuthException? throwOnVerify;
  bool unsupported = false;
  String? lastPhone;
  int? lastResendToken;

  @override
  Future<void> verifyPhoneNumber({
    String? phoneNumber,
    PhoneMultiFactorInfo? multiFactorInfo,
    required PhoneVerificationCompleted verificationCompleted,
    required PhoneVerificationFailed verificationFailed,
    required PhoneCodeSent codeSent,
    required PhoneCodeAutoRetrievalTimeout codeAutoRetrievalTimeout,
    String? autoRetrievedSmsCodeForTesting,
    Duration timeout = const Duration(seconds: 30),
    int? forceResendingToken,
    MultiFactorSession? multiFactorSession,
  }) async {
    lastPhone = phoneNumber;
    lastResendToken = forceResendingToken;
    if (unsupported) throw UnimplementedError();
    final error = throwOnVerify;
    if (error != null) throw error;
    await script?.call(
      completed: verificationCompleted,
      failed: verificationFailed,
      sent: codeSent,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
