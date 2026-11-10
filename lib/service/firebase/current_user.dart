import 'package:firebase_auth/firebase_auth.dart';

/// Read-only identity of the user authenticated in Firebase Auth, for other
/// modules that need to scope their data (e.g. filter reservations by
/// `CurrentUser.uid`).
///
/// It only identifies the user. It never grants permissions: the role and the
/// authorization are enforced by Firestore security rules in the backend. For
/// the display-only shared email see `AuthPreferences`.
abstract final class CurrentUser {
  /// Uid of the signed-in user, or `null` when there is no session.
  static String? get uid => FirebaseAuth.instance.currentUser?.uid;

  /// Email of the signed-in user, or `null` when there is no session.
  static String? get email => FirebaseAuth.instance.currentUser?.email;

  /// Like [uid], but `null` instead of throwing when Firebase is not
  /// initialized (widget tests, demo mode). Use it to fall back to demo ids.
  static String? get uidOrNull {
    try {
      return uid;
    } catch (_) {
      return null;
    }
  }

  /// Like [email], but `null` instead of throwing when Firebase is not
  /// initialized.
  static String? get emailOrNull {
    try {
      return email;
    } catch (_) {
      return null;
    }
  }

  /// Whether a Firebase session exists right now.
  static bool get isSignedIn => FirebaseAuth.instance.currentUser != null;
}
