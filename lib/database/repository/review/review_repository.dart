import 'package:machuco/models/review/review.dart';
import 'package:machuco/database/repository/review/review_seed_data.dart';

/// Error al leer o escribir reseñas, sin importar el origen de datos.
///
/// [message] ya está listo para mostrarse al usuario.
class ReviewRepositoryException implements Exception {
  const ReviewRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}

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

  /// Elimina la reseña con [id]. Las implementaciones remotas solo lo
  /// permiten al administrador.
  Future<void> delete(String id);

  /// Guarda [reply] como respuesta del propietario a la reseña [reviewId].
  ///
  /// Las implementaciones remotas validan en el servidor que la reseña sea
  /// de un motel del usuario con sesión; si no, lanzan
  /// `ReviewRepositoryException`.
  Future<void> replyAsOwner(String reviewId, String reply);

  /// El propietario reporta la reseña al administrador con [reason]: pasa a
  /// `reported`. Las implementaciones remotas validan que el motel sea suyo y
  /// que la reseña esté visible.
  Future<void> reportAsOwner(String reviewId, String reason);

  /// Moderación del administrador: oculta ([hidden] = true) o muestra la
  /// reseña. Las implementaciones remotas exigen el rol de administrador.
  Future<void> setHiddenAsAdmin(String reviewId, {required bool hidden});

  /// Descarta el reporte: la reseña vuelve a `visible` y sin motivo.
  Future<void> dismissReportAsAdmin(String reviewId);

  Future<void> replyAsAdmin(String reviewId, String reply);
}

/// Implementación en memoria, sembrada con [reviewSeedData].
///
/// Solo para pruebas: las pantallas usan SQL Connect por defecto.
class InMemoryReviewRepository implements ReviewRepository {
  InMemoryReviewRepository({List<Review>? seed})
    : _reviews = [...seed ?? reviewSeedData()];

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
  Future<void> replyAsOwner(String reviewId, String reply) async =>
      _change(reviewId, (r) => r.copyWith(ownerReply: reply));

  @override
  Future<void> reportAsOwner(String reviewId, String reason) async => _change(
    reviewId,
    (r) => r.copyWith(
      status: ReviewModerationStatus.reported,
      reportReason: reason,
    ),
  );

  @override
  Future<void> setHiddenAsAdmin(
    String reviewId, {
    required bool hidden,
  }) async => _change(
    reviewId,
    (r) => r.copyWith(
      status: hidden
          ? ReviewModerationStatus.hidden
          : ReviewModerationStatus.visible,
    ),
  );

  @override
  Future<void> dismissReportAsAdmin(String reviewId) async => _change(
    reviewId,
    (r) => r.copyWith(
      status: ReviewModerationStatus.visible,
      clearReportReason: true,
    ),
  );

  @override
  Future<void> replyAsAdmin(String reviewId, String reply) async =>
      _change(reviewId, (r) => r.copyWith(adminReply: reply));

  void _change(String reviewId, Review Function(Review review) change) {
    final index = _reviews.indexWhere((r) => r.id == reviewId);
    if (index != -1) _reviews[index] = change(_reviews[index]);
  }
}
