/// Single place for Cloud Firestore collection names.
///
/// Every repository must reference these constants instead of repeating string
/// literals, and every new collection needs an explicit rule in
/// `firestore.rules` (the default is deny).
abstract final class FirestoreCollections {
  /// User profiles, one document per Firebase Auth uid (`users/{uid}`).
  static const users = 'users';
}
