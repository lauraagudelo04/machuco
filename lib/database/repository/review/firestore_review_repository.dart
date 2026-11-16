import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:machuco/database/repository/review/review_repository.dart';
import 'package:machuco/models/review/review.dart';
import 'package:machuco/service/firebase/firestore_collections.dart';

/// Error al leer o escribir reseñas en Cloud Firestore.
class ReviewRepositoryException implements Exception {
  const ReviewRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// [ReviewRepository] respaldado por la colección `reviews` de Cloud Firestore.
///
/// Cada reseña es un documento cuyo id es [Review.id]. La autorización (que un
/// cliente solo publique a su nombre, quién puede moderar) la imponen las
/// reglas de `firestore.rules`, no esta clase.
///
/// No toca Firebase hasta la primera operación, así crear el controlador no
/// requiere Firebase inicializado (por ejemplo, en pruebas).
class FirestoreReviewRepository implements ReviewRepository {
  FirestoreReviewRepository({this._firestore});

  FirebaseFirestore? _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      (_firestore ??= FirebaseFirestore.instance).collection(
        FirestoreCollections.reviews,
      );

  /// Devuelve todas las reseñas, de la más reciente a la más antigua.
  ///
  /// Los documentos con un formato inesperado se omiten para que una sola
  /// reseña dañada no deje vacía la pantalla.
  @override
  Future<List<Review>> getAll() async {
    final QuerySnapshot<Map<String, dynamic>> snapshot;
    try {
      snapshot = await _collection.orderBy('date', descending: true).get();
    } on FirebaseException catch (e) {
      throw ReviewRepositoryException(_messageFor(e));
    }
    return [
      for (final doc in snapshot.docs) ?reviewFromFirestore(doc.id, doc.data()),
    ];
  }

  @override
  Future<void> add(Review review) =>
      _write(() => _collection.doc(review.id).set(reviewToFirestore(review)));

  /// Reemplaza la reseña con el mismo [Review.id]. No hace nada si no existe.
  @override
  Future<void> update(Review review) => _write(() async {
    final doc = _collection.doc(review.id);
    if (!(await doc.get()).exists) return;
    await doc.set(reviewToFirestore(review));
  });

  @override
  Future<void> delete(String id) => _write(() => _collection.doc(id).delete());

  Future<void> _write(Future<void> Function() operation) async {
    try {
      await operation();
    } on FirebaseException catch (e) {
      throw ReviewRepositoryException(_messageFor(e));
    }
  }

  static String _messageFor(FirebaseException e) => switch (e.code) {
    'permission-denied' => 'No tienes permiso para esta acción sobre reseñas',
    'unavailable' => 'No hay conexión con el servidor de reseñas',
    _ => 'No fue posible acceder a las reseñas',
  };
}

/// Convierte [review] en los campos del documento de Firestore.
///
/// Los opcionales vacíos se omiten en vez de guardarse como `null`.
Map<String, dynamic> reviewToFirestore(Review review) => {
  'authorId': review.authorId,
  'authorName': review.authorName,
  'title': review.title,
  'body': review.body,
  'rating': review.rating,
  'date': Timestamp.fromDate(review.date),
  'motelId': review.motelId,
  'roomId': ?review.roomId,
  'type': review.type.name,
  'status': review.status.name,
  'reportReason': ?review.reportReason,
  'adminReply': ?review.adminReply,
  'ownerReply': ?review.ownerReply,
};

/// Reconstruye la reseña [id] a partir de [data], o devuelve `null` si al
/// documento le faltan campos obligatorios o tienen otro tipo.
Review? reviewFromFirestore(String id, Map<String, dynamic> data) {
  if (data case {
    'authorId': final String authorId,
    'authorName': final String authorName,
    'title': final String title,
    'body': final String body,
    'rating': final num rating,
    'date': final Timestamp date,
    'motelId': final String motelId,
  }) {
    return Review(
      id: id,
      authorId: authorId,
      authorName: authorName,
      title: title,
      body: body,
      rating: rating.toInt(),
      date: date.toDate(),
      motelId: motelId,
      roomId: _optionalString(data['roomId']),
      type: ReviewType.fromString(_optionalString(data['type']) ?? ''),
      status:
          ReviewModerationStatus.values.asNameMap()[data['status']] ??
          ReviewModerationStatus.visible,
      reportReason: _optionalString(data['reportReason']),
      adminReply: _optionalString(data['adminReply']),
      ownerReply: _optionalString(data['ownerReply']),
    );
  }
  return null;
}

String? _optionalString(Object? value) => value is String ? value : null;
