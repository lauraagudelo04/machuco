import 'package:flutter/foundation.dart';
import 'package:machuco/models/review/review.dart';
// Prefijo aparte: el getter [averageRating] tapa el nombre de la función de
// dominio del mismo nombre dentro de la clase.
import 'package:machuco/database/repository/review/firestore_review_repository.dart';
import 'package:machuco/database/repository/review/review_repository.dart';
import 'package:machuco/database/repository/review/sql_connect_review_repository.dart';

/// Filtros disponibles en el panel de administración de reseñas.
enum ReviewFilter { all, visible, hidden, reported }

extension ReviewFilterData on ReviewFilter {
  String get label => switch (this) {
    ReviewFilter.all => 'Todas',
    ReviewFilter.visible => 'Visibles',
    ReviewFilter.hidden => 'Ocultas',
    ReviewFilter.reported => 'Reportadas',
  };
}

/// Controlador del panel de administración de reseñas.
///
/// Opera directamente sobre el modelo [Review]; ya no usa wrappers
/// [AdminReviewEntry] porque todos los campos de moderación viven ahora
/// en el modelo mismo.
class ReviewAdministrationController extends ChangeNotifier {
  ReviewAdministrationController({ReviewRepository? repository})
    : _repository = repository ?? SqlConnectReviewRepository();

  final ReviewRepository _repository;
  final List<Review> _reviews = [];
  ReviewFilter _filter = ReviewFilter.all;
  String _query = '';
  bool _isLoading = false;
  String? _errorMessage;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  ReviewFilter get filter => _filter;
  String get query => _query;

  Future<void> loadReviews() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final reviews = await _repository.getAll();
      _reviews
        ..clear()
        ..addAll(reviews);
    } catch (_) {
      _errorMessage = 'No fue posible cargar las reseñas.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  List<Review> get reviews {
    final normalizedQuery = _query.trim().toLowerCase();
    return _reviews
        .where((review) {
          final matchesFilter = switch (_filter) {
            ReviewFilter.all => true,
            ReviewFilter.visible =>
              review.status == ReviewModerationStatus.visible,
            ReviewFilter.hidden =>
              review.status == ReviewModerationStatus.hidden,
            ReviewFilter.reported =>
              review.status == ReviewModerationStatus.reported,
          };
          if (!matchesFilter) return false;
          if (normalizedQuery.isEmpty) return true;
          return review.authorName.toLowerCase().contains(normalizedQuery) ||
              review.title.toLowerCase().contains(normalizedQuery) ||
              review.body.toLowerCase().contains(normalizedQuery);
        })
        .toList(growable: false);
  }

  int get totalCount => _reviews.length;

  int get reportedCount =>
      _reviews.where((r) => r.status == ReviewModerationStatus.reported).length;

  double get averageRating => averageRatingOf(_reviews);

  void setFilter(ReviewFilter filter) {
    _filter = filter;
    notifyListeners();
  }

  void setQuery(String query) {
    _query = query;
    notifyListeners();
  }

  // Cada acción devuelve null si se guardó (o si no había nada que hacer) y
  // el motivo en texto si el servidor la rechazó; en ese caso la reseña no
  // cambia en pantalla.

  Future<String?> toggleVisibility(String reviewId) {
    final review = _find(reviewId);
    if (review == null) return Future.value();
    final hide = review.status != ReviewModerationStatus.hidden;
    return _apply(
      reviewId,
      () => _repository.setHiddenAsAdmin(reviewId, hidden: hide),
      (r) => r.copyWith(
        status: hide
            ? ReviewModerationStatus.hidden
            : ReviewModerationStatus.visible,
      ),
    );
  }

  Future<String?> dismissReport(String reviewId) => _apply(
    reviewId,
    () => _repository.dismissReportAsAdmin(reviewId),
    (r) => r.copyWith(
      status: ReviewModerationStatus.visible,
      clearReportReason: true,
    ),
  );

  Future<String?> reply(String reviewId, String message) {
    final trimmed = message.trim();
    if (trimmed.isEmpty) return Future.value();
    return _apply(
      reviewId,
      () => _repository.replyAsAdmin(reviewId, trimmed),
      (r) => r.copyWith(adminReply: trimmed),
    );
  }

  Future<String?> delete(String reviewId) async {
    try {
      await _repository.delete(reviewId);
    } on ReviewRepositoryException catch (error) {
      return error.message;
    }
    _reviews.removeWhere((r) => r.id == reviewId);
    notifyListeners();
    return null;
  }

  Review? _find(String reviewId) {
    for (final review in _reviews) {
      if (review.id == reviewId) return review;
    }
    return null;
  }

  /// Guarda con [save] y, si el servidor lo acepta, aplica [change] a la
  /// reseña en pantalla. Ignora ids desconocidos.
  Future<String?> _apply(
    String reviewId,
    Future<void> Function() save,
    Review Function(Review review) change,
  ) async {
    if (_find(reviewId) == null) return null;
    try {
      await save();
    } on ReviewRepositoryException catch (error) {
      return error.message;
    }
    final index = _reviews.indexWhere((r) => r.id == reviewId);
    if (index != -1) _reviews[index] = change(_reviews[index]);
    notifyListeners();
    return null;
  }
}
