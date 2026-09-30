import 'package:flutter/foundation.dart';
import 'package:machuco/models/review/review.dart';
import 'package:machuco/models/review/review_data.dart';

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
  final List<Review> _reviews = [];
  ReviewFilter _filter = ReviewFilter.all;
  String _query = '';
  bool _isLoading = false;
  String? _errorMessage;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  ReviewFilter get filter => _filter;
  String get query => _query;

  /// TODO: reemplazar la carga de ejemplo por la fuente real de reseñas
  /// (repositorio/backend) cuando el equipo la tenga lista.
  Future<void> loadReviews() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      if (_reviews.isEmpty) {
        _reviews.addAll(ReviewData.all());
      }
    } catch (_) {
      _errorMessage = 'No fue posible cargar las reseñas.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  List<Review> get reviews {
    final normalizedQuery = _query.trim().toLowerCase();
    return _reviews.where((review) {
      final matchesFilter = switch (_filter) {
        ReviewFilter.all => true,
        ReviewFilter.visible =>
          review.status == ReviewModerationStatus.visible,
        ReviewFilter.hidden => review.status == ReviewModerationStatus.hidden,
        ReviewFilter.reported =>
          review.status == ReviewModerationStatus.reported,
      };
      if (!matchesFilter) return false;
      if (normalizedQuery.isEmpty) return true;
      return review.authorName.toLowerCase().contains(normalizedQuery) ||
          review.title.toLowerCase().contains(normalizedQuery) ||
          review.body.toLowerCase().contains(normalizedQuery);
    }).toList(growable: false);
  }

  int get totalCount => _reviews.length;

  int get reportedCount => _reviews
      .where((r) => r.status == ReviewModerationStatus.reported)
      .length;

  double get averageRating => _reviews.isEmpty
      ? 0
      : _reviews.map((r) => r.rating).reduce((a, b) => a + b) /
          _reviews.length;

  void setFilter(ReviewFilter filter) {
    _filter = filter;
    notifyListeners();
  }

  void setQuery(String query) {
    _query = query;
    notifyListeners();
  }

  void toggleVisibility(String reviewId) {
    final review = _reviews.firstWhere((r) => r.id == reviewId);
    _reviews[_reviews.indexOf(review)] = review.copyWith(
      status: review.status == ReviewModerationStatus.hidden
          ? ReviewModerationStatus.visible
          : ReviewModerationStatus.hidden,
    );
    notifyListeners();
  }

  void dismissReport(String reviewId) {
    final review = _reviews.firstWhere((r) => r.id == reviewId);
    _reviews[_reviews.indexOf(review)] = review.copyWith(
      status: ReviewModerationStatus.visible,
      reportReason: null,
    );
    notifyListeners();
  }

  void reply(String reviewId, String message) {
    final trimmed = message.trim();
    if (trimmed.isEmpty) return;
    final review = _reviews.firstWhere((r) => r.id == reviewId);
    _reviews[_reviews.indexOf(review)] = review.copyWith(adminReply: trimmed);
    notifyListeners();
  }

  void delete(String reviewId) {
    _reviews.removeWhere((r) => r.id == reviewId);
    notifyListeners();
  }
}