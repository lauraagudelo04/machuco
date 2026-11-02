import 'package:flutter/foundation.dart';
import 'package:machuco/models/review/review.dart';
// Prefijo aparte: el getter [averageRating] tapa el nombre de la función de
// dominio del mismo nombre dentro de la clase.
import 'package:machuco/database/repository/review/review_repository.dart';

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
    : _repository = repository ?? InMemoryReviewRepository.shared;

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

  Future<void> toggleVisibility(String reviewId) => _updateWhere(
    reviewId,
    (review) => review.copyWith(
      status: review.status == ReviewModerationStatus.hidden
          ? ReviewModerationStatus.visible
          : ReviewModerationStatus.hidden,
    ),
  );

  Future<void> dismissReport(String reviewId) => _updateWhere(
    reviewId,
    (review) => review.copyWith(
      status: ReviewModerationStatus.visible,
      clearReportReason: true,
    ),
  );

  Future<void> reply(String reviewId, String message) async {
    final trimmed = message.trim();
    if (trimmed.isEmpty) return;
    await _updateWhere(
      reviewId,
      (review) => review.copyWith(adminReply: trimmed),
    );
  }

  Future<void> delete(String reviewId) async {
    await _repository.delete(reviewId);
    _reviews.removeWhere((r) => r.id == reviewId);
    notifyListeners();
  }

  /// Aplica [change] a la reseña [reviewId]; ignora ids desconocidos.
  Future<void> _updateWhere(
    String reviewId,
    Review Function(Review review) change,
  ) async {
    final index = _reviews.indexWhere((r) => r.id == reviewId);
    if (index == -1) return;
    final updated = change(_reviews[index]);
    await _repository.update(updated);
    _reviews[index] = updated;
    notifyListeners();
  }
}
