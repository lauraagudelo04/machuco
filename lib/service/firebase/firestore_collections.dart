/// Single place for Cloud Firestore collection names.
///
/// Every repository must reference these constants instead of repeating string
/// literals, and every new collection needs an explicit rule in
/// `firestore.rules` (the default is deny).
abstract final class FirestoreCollections {
  /// User profiles, one document per Firebase Auth uid (`users/{uid}`).
  static const users = 'users';

  static const subscriptions = 'subscriptions';

  /// Payment records synchronized from the owner's local SQLite database.
  static const payments = 'payments';

  /// Additional services offered by a motel (`additionalServices/{id}`).
  static const additionalServices = 'additionalServices';

  /// Reservations shared by client, motel owner and admin
  /// (`reservations/{reservationId}`), cached locally in SQLite.
  static const reservations = 'reservations';
}
