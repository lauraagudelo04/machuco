/// Single place for Cloud Firestore collection names.
///
/// Every repository must reference these constants instead of repeating string
/// literals, and every new collection needs an explicit rule in
/// `firestore.rules` (the default is deny).
abstract final class FirestoreCollections {
  /// User profiles, one document per Firebase Auth uid (`users/{uid}`).
  static const users = 'users';

  static const subscriptions = 'subscriptions';

  /// Pagos de una suscripción. Solo se usa como subcolección de
  /// `users/{uid}/subscriptions/{subscriptionId}`; no es la colección global
  /// de pagos de reservas (`payments` en la raíz).
  /// Ruta canónica compatible con las reglas entregadas: al estar anidada
  /// debajo de `subscriptions`, no se mezcla con `payments` de la raíz.
  static const subscriptionPayments = 'subscriptionPayments';

  /// Ruta antigua anidada, conservada para leer datos existentes.

  /// Payment records synchronized from the owner's local SQLite database.
  static const rooms = 'rooms';
  static const roomTypes = 'room_types';
  static const roomMotels = 'room_motels';

  static const payments = 'payments';

  /// Copia de los moteles de Firebase SQL Connect (`motels/{motelId}`, mismo
  /// UUID), para que otros módulos y sus reglas los consulten en Firestore.
  static const motels = 'motels';

  /// Additional services offered by a motel (`additionalServices/{id}`).
  static const additionalServices = 'additionalServices';

  /// Reservations shared by client, motel owner and admin
  /// (`reservations/{reservationId}`), cached locally in SQLite.
  static const reservations = 'reservations';
}
