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

  /// Reseñas de clientes a moteles o habitaciones (`reviews/{reviewId}`).
  ///
  /// El id del documento es el id de la reseña; la fecha vive en el campo
  /// `date` (Timestamp) para poder ordenar la lista.
  static const reviews = 'reviews';
}
