import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:machuco/models/auth/phone_verification.dart';
import 'package:machuco/service/auth/auth_service.dart';

/// Sends and checks SMS codes to verify a phone number at sign-up.
///
/// `FirebasePhoneVerificationService` is the only production implementation;
/// the contract is the seam to inject a fake in tests. The code is not checked
/// here: Firebase validates it when the proof is linked to the user (see
/// [linkVerifiedPhone]), so the check always happens on the server.
abstract interface class PhoneVerificationService {
  /// Sends an SMS with a code to [phoneNumber] (E.164). Pass the previous
  /// request as [resendFrom] to resend it. Throws [AuthFailure].
  Future<PhoneCodeRequest> sendCode({
    required String phoneNumber,
    PhoneCodeRequest? resendFrom,
  });

  /// Turns the code typed by the user into a proof for the account creation
  /// step. Throws [AuthFailureType.invalidVerificationCode] if [smsCode] is
  /// not a 6 digit code.
  PhoneVerificationProof buildProof({
    required PhoneCodeRequest request,
    required String smsCode,
  });
}

/// [PhoneVerificationProof] backed by a Firebase [PhoneAuthCredential].
final class FirebasePhoneVerificationProof implements PhoneVerificationProof {
  const FirebasePhoneVerificationProof({
    required this.phoneNumber,
    required this.credential,
  });

  @override
  final String phoneNumber;
  final PhoneAuthCredential credential;

  // Sin toString: la credencial lleva el código SMS.
}

/// [PhoneVerificationService] using Firebase Authentication phone auth.
final class FirebasePhoneVerificationService
    implements PhoneVerificationService {
  FirebasePhoneVerificationService({
    FirebaseAuth? firebaseAuth,
    this._smsTimeout = defaultSmsTimeout,
    this._responseTimeout = defaultResponseTimeout,
  }) : _auth = firebaseAuth ?? FirebaseAuth.instance;

  /// Time the platform waits for the SMS auto-retrieval (Android).
  static const defaultSmsTimeout = Duration(seconds: 60);

  /// Time the app waits for Firebase to answer before giving up.
  static const defaultResponseTimeout = Duration(seconds: 90);

  /// Length of the code Firebase sends.
  static const codeLength = 6;

  final FirebaseAuth _auth;
  final Duration _smsTimeout;
  final Duration _responseTimeout;

  @override
  Future<PhoneCodeRequest> sendCode({
    required String phoneNumber,
    PhoneCodeRequest? resendFrom,
  }) async {
    final completer = Completer<PhoneCodeRequest>();
    // Firebase puede responder antes de que se espere el resultado: sin esto
    // ese error llegaría a la zona como excepción sin manejar.
    completer.future.ignore();

    void fail(AuthFailure failure) {
      if (!completer.isCompleted) completer.completeError(failure);
    }

    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        timeout: _smsTimeout,
        forceResendingToken: resendFrom?.resendToken,
        verificationCompleted: (credential) {
          // Only arrives first on instant verification; when the SMS was
          // already sent the user types the code and this is ignored.
          if (completer.isCompleted) return;
          completer.complete(
            PhoneCodeRequest(
              phoneNumber: phoneNumber,
              verificationId: credential.verificationId ?? '',
              autoVerifiedProof: FirebasePhoneVerificationProof(
                phoneNumber: phoneNumber,
                credential: credential,
              ),
            ),
          );
        },
        verificationFailed: (error) => fail(phoneAuthFailureFor(error)),
        codeSent: (verificationId, resendToken) {
          if (completer.isCompleted) return;
          completer.complete(
            PhoneCodeRequest(
              phoneNumber: phoneNumber,
              verificationId: verificationId,
              resendToken: resendToken,
            ),
          );
        },
        codeAutoRetrievalTimeout: (_) {},
      );
    } on FirebaseAuthException catch (error) {
      throw phoneAuthFailureFor(error);
    } on UnimplementedError catch (error) {
      debugPrint('Verificación por SMS no soportada: $error');
      throw const AuthFailure(
        AuthFailureType.providerMisconfigured,
        'La verificación por SMS no está disponible en esta plataforma.',
      );
    }

    return completer.future.timeout(
      _responseTimeout,
      onTimeout: () => throw const AuthFailure(
        AuthFailureType.network,
        'No recibimos respuesta. Revisa tu conexión e intenta nuevamente.',
      ),
    );
  }

  @override
  PhoneVerificationProof buildProof({
    required PhoneCodeRequest request,
    required String smsCode,
  }) {
    final code = smsCode.trim();
    if (!RegExp('^[0-9]{$codeLength}\$').hasMatch(code)) {
      throw const AuthFailure(
        AuthFailureType.invalidVerificationCode,
        'Escribe el código de $codeLength dígitos que recibiste por SMS.',
      );
    }
    return FirebasePhoneVerificationProof(
      phoneNumber: request.phoneNumber,
      credential: PhoneAuthProvider.credential(
        verificationId: request.verificationId,
        smsCode: code,
      ),
    );
  }
}

/// The proof for [phoneNumber], or [AuthFailureType.phoneNotVerified] if it is
/// missing, was not issued by Firebase, or belongs to a different number than
/// the one being registered (verify one number, register another).
FirebasePhoneVerificationProof requireVerifiedPhoneProof(
  PhoneVerificationProof? proof, {
  required String phoneNumber,
}) {
  if (proof is FirebasePhoneVerificationProof &&
      proof.phoneNumber == phoneNumber) {
    return proof;
  }
  throw const AuthFailure(
    AuthFailureType.phoneNotVerified,
    'Verifica tu número de celular para continuar.',
  );
}

/// Links the verified phone to [user]. Firebase checks the SMS code here, so a
/// wrong or expired code fails with an [AuthFailure]; a phone that already
/// belongs to another account fails with [AuthFailureType.phoneAlreadyInUse].
Future<void> linkVerifiedPhone(
  User user,
  FirebasePhoneVerificationProof proof,
) async {
  try {
    await user.linkWithCredential(proof.credential);
  } on FirebaseAuthException catch (error) {
    // Retry after a cut: the number was already linked to this same user.
    if (error.code == 'provider-already-linked' &&
        user.phoneNumber == proof.phoneNumber) {
      return;
    }
    throw phoneAuthFailureFor(error);
  }
}

/// Translates a Firebase phone-auth error into a user-safe [AuthFailure].
AuthFailure phoneAuthFailureFor(FirebaseAuthException error) {
  debugPrint('Verificación por SMS falló: ${error.code}');
  return switch (error.code) {
    'invalid-phone-number' || 'missing-phone-number' => const AuthFailure(
      AuthFailureType.invalidInput,
      'El número de celular no es válido para recibir el SMS.',
    ),
    'invalid-verification-code' => const AuthFailure(
      AuthFailureType.invalidVerificationCode,
      'El código no es correcto. Revísalo e intenta de nuevo.',
    ),
    'invalid-verification-id' || 'session-expired' => const AuthFailure(
      AuthFailureType.verificationExpired,
      'El código venció. Solicita uno nuevo.',
    ),
    'credential-already-in-use' ||
    'account-exists-with-different-credential' => const AuthFailure(
      AuthFailureType.phoneAlreadyInUse,
      'Este celular ya está asociado a otra cuenta.',
    ),
    'too-many-requests' => const AuthFailure(
      AuthFailureType.tooManyRequests,
      'Demasiados intentos. Espera unos minutos e intenta nuevamente.',
    ),
    'quota-exceeded' => const AuthFailure(
      AuthFailureType.tooManyRequests,
      'Se alcanzó el límite de mensajes SMS. Intenta más tarde.',
    ),
    'network-request-failed' => const AuthFailure(
      AuthFailureType.network,
      'No hay conexión. Revisa tu internet e intenta nuevamente.',
    ),
    'operation-not-allowed' ||
    'app-not-authorized' ||
    'captcha-check-failed' ||
    'invalid-app-credential' ||
    'missing-app-credential' ||
    'missing-client-identifier' ||
    'play-integrity-token-request-failed' ||
    'web-internal-error' => const AuthFailure(
      AuthFailureType.providerMisconfigured,
      'La verificación por SMS no está disponible en esta versión de la app.',
    ),
    _ => const AuthFailure(
      AuthFailureType.unknown,
      'No fue posible verificar tu celular. Intenta nuevamente.',
    ),
  };
}
