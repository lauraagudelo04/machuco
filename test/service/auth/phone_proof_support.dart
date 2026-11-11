import 'package:firebase_auth/firebase_auth.dart';
import 'package:machuco/service/auth/phone_verification_service.dart';

/// Prueba de verificación con una credencial SMS real de Firebase (solo datos;
/// no llama a la red hasta que se vincula).
FirebasePhoneVerificationProof phoneProof(
  String phoneNumber, {
  String smsCode = '123456',
}) => FirebasePhoneVerificationProof(
  phoneNumber: phoneNumber,
  credential: PhoneAuthProvider.credential(
    verificationId: 'verification-id',
    smsCode: smsCode,
  ),
);
