import 'package:flutter/foundation.dart';
import 'package:machuco/database/repository/review/review_repository.dart';
import 'package:machuco/models/review/review.dart';

/// Acciones sobre las reseñas que muestra un controlador (responder,
/// reportar, moderar, eliminar).
///
/// Todas siguen el mismo protocolo: primero se guarda en el servidor y solo
/// si lo acepta cambia la reseña en pantalla. Cada acción devuelve `null` si
/// salió bien, o el motivo del rechazo para mostrarlo al usuario.
mixin ReviewActions on ChangeNotifier {
  /// Reseñas que muestra la pantalla; [saveReview] las actualiza.
  List<Review> get shownReviews;

  /// Guarda con [save] y, si el servidor lo acepta, reemplaza la reseña
  /// [reviewId] por lo que devuelva [change] (o la quita si devuelve `null`).
  ///
  /// Si la reseña no está en pantalla no hace nada y devuelve `null`.
  Future<String?> saveReview(
    String reviewId, {
    required Future<void> Function() save,
    required Review? Function(Review review) change,
  }) async {
    if (findShownReview(reviewId) == null) return null;
    try {
      await save();
    } on ReviewRepositoryException catch (error) {
      return error.message;
    }
    // Se busca de nuevo: la lista pudo recargarse mientras se guardaba.
    final index = shownReviews.indexWhere((review) => review.id == reviewId);
    if (index == -1) return null;
    final updated = change(shownReviews[index]);
    if (updated == null) {
      shownReviews.removeAt(index);
    } else {
      shownReviews[index] = updated;
    }
    notifyListeners();
    return null;
  }

  Review? findShownReview(String reviewId) {
    for (final review in shownReviews) {
      if (review.id == reviewId) return review;
    }
    return null;
  }
}
