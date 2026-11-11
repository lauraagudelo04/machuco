/// Evidence that the user proved ownership of [phoneNumber] with an SMS code.
///
/// It is opaque on purpose: views and controllers only carry it from the
/// verification step to the account creation step. The service that issued it
/// (`FirebasePhoneVerificationProof`) is the only one that knows how to link
/// the phone number to the Firebase user.
abstract interface class PhoneVerificationProof {
  /// Number in E.164 format (dial code included), e.g. `+573001234567`.
  String get phoneNumber;
}

/// An SMS code that was requested for [phoneNumber].
///
/// [verificationId] and [resendToken] only make sense for the service that
/// created the request; callers hand it back to that same service to resend
/// the code or to turn the typed code into a [PhoneVerificationProof].
final class PhoneCodeRequest {
  const PhoneCodeRequest({
    required this.phoneNumber,
    required this.verificationId,
    this.resendToken,
    this.autoVerifiedProof,
  });

  /// Number in E.164 format the code was sent to.
  final String phoneNumber;

  /// Firebase session id tied to the code that was sent.
  final String verificationId;

  /// Lets the platform resend the SMS without a new reCAPTCHA / integrity check.
  final int? resendToken;

  /// Set when the platform verified the number without asking for a code
  /// (Android instant verification). The code field is then not needed.
  final PhoneVerificationProof? autoVerifiedProof;
}
