import 'package:machuco/models/review/review.dart';
import 'package:machuco/database/repository/review/review_seed_data.dart';

/// Contrato de acceso a las reseñas, independiente del origen de datos.
///
/// Los controladores de cliente, propietario y administrador dependen de
/// este contrato. Cuando el equipo decida el almacenamiento definitivo
/// (Supabase, Firestore...), solo cambia la implementación.
abstract class ReviewRepository {
  Future<List<Review>> getAll();

  Future<void> add(Review review);

  /// Reemplaza la reseña con el mismo [Review.id]. No hace nada si no existe.
  Future<void> update(Review review);

  /// Elimina la reseña con [id]. No hace nada si no existe.
  Future<void> delete(String id);

  /// Guarda [reply] como respuesta del propietario a la reseña [reviewId].
  ///
  /// Las implementaciones remotas validan en el servidor que la reseña sea
  /// de un motel del usuario con sesión; si no, lanzan
  /// `ReviewRepositoryException`.
  Future<void> replyAsOwner(String reviewId, String reply);
}

/// Implementación en memoria, sembrada con [reviewSeedData].
///
/// [shared] es la instancia que usan las pantallas por defecto: así una
/// respuesta del propietario la ve el administrador y una reseña nueva del
/// cliente la ven los demás roles. Las pruebas crean instancias propias.
class InMemoryReviewRepository implements ReviewRepository {
  InMemoryReviewRepository({List<Review>? seed})
    : _reviews = [...seed ?? reviewSeedData()];

  static final InMemoryReviewRepository shared = InMemoryReviewRepository();

  final List<Review> _reviews;

  @override
  Future<List<Review>> getAll() async => List.unmodifiable(_reviews);

  @override
  Future<void> add(Review review) async => _reviews.insert(0, review);

  @override
  Future<void> update(Review review) async {
    final index = _reviews.indexWhere((r) => r.id == review.id);
    if (index != -1) _reviews[index] = review;
  }

  @override
  Future<void> delete(String id) async =>
      _reviews.removeWhere((r) => r.id == id);

  @override
  Future<void> replyAsOwner(String reviewId, String reply) async {
    final index = _reviews.indexWhere((r) => r.id == reviewId);
    if (index != -1) {
      _reviews[index] = _reviews[index].copyWith(ownerReply: reply);
    }
  }
}
