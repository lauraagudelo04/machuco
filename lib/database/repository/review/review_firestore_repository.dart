import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:machuco/database/repository/review/review_repository.dart';
import 'package:machuco/models/review/review.dart';
import 'package:machuco/service/firebase/firestore_collections.dart';

/// Categoría de un [ReviewRepositoryException], para que quien llama trate
/// distinto un error de red (reintentable, la sesión sigue viva) del resto.
enum ReviewRepositoryFailureType { permissionDenied, network, unknown }

/// Error de un [ReviewRepository]; [message] se puede mostrar (en español).
class ReviewRepositoryException implements Exception {
  const ReviewRepositoryException(this.type, this.message);

  final ReviewRepositoryFailureType type;
  final String message;

  @override
  String toString() => message;
}

/// [ReviewRepository] respaldado por Cloud Firestore, en `reviews/{id}`.
///
/// La autorización la impone `firestore.rules`, no esta clase: aquí solo se
/// traduce `FirebaseException` a [ReviewRepositoryException].
///
/// Para activarla, reemplaza `InMemoryReviewRepository.shared` por
/// `FirestoreReviewRepository()` donde los controladores construyen su
/// repositorio por defecto (`add_review_controller.dart`,
/// `owner_review_controller.dart` y `review_administration_controller.dart`).
/// Todavía no es el valor por defecto porque la regla de `reviews` en
/// `firestore.rules` no está desplegada y la app fallaría con
/// `permission-denied`.
class FirestoreReviewRepository implements ReviewRepository {
  FirestoreReviewRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(FirestoreCollections.reviews);

  DocumentReference<Map<String, dynamic>> _doc(String id) =>
      _collection.doc(id);

  @override
  Future<List<Review>> getAll() async {
    try {
      final snapshot = await _collection
          .orderBy('date', descending: true)
          .get();
      return List.unmodifiable(
        snapshot.docs.map((doc) => Review.fromFirestore(doc.id, doc.data())),
      );
    } on FirebaseException catch (e) {
      throw _map(e);
    }
  }

  @override
  Future<void> add(Review review) async {
    try {
      await _collection.add(review.toFirestore());
    } on FirebaseException catch (e) {
      throw _map(e);
    }
  }

  @override
  Future<void> update(Review review) async {
    try {
      await _doc(review.id).set(review.toFirestore(), SetOptions(merge: true));
    } on FirebaseException catch (e) {
      throw _map(e);
    }
  }

  @override
  Future<void> delete(String id) async {
    try {
      await _doc(id).delete();
    } on FirebaseException catch (e) {
      throw _map(e);
    }
  }

  ReviewRepositoryException _map(FirebaseException e) {
    debugPrint('Firestore reviews error: ${e.code}');
    return switch (e.code) {
      'permission-denied' ||
      'unauthenticated' => const ReviewRepositoryException(
        ReviewRepositoryFailureType.permissionDenied,
        'No tienes permisos para realizar esta operación.',
      ),
      'unavailable' || 'deadline-exceeded' => const ReviewRepositoryException(
        ReviewRepositoryFailureType.network,
        'No hay conexión. Revisa tu internet e intenta nuevamente.',
      ),
      _ => const ReviewRepositoryException(
        ReviewRepositoryFailureType.unknown,
        'Ocurrió un error inesperado. Intenta nuevamente.',
      ),
    };
  }
}
