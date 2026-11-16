import 'package:flutter/foundation.dart';
import 'package:machuco/controllers/review/review_actions.dart';
import 'package:machuco/models/review/review.dart';
// Prefijo aparte: el getter [averageRating] tapa el nombre de la función de
// dominio del mismo nombre dentro de la clase.
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
class ReviewAdministrationController extends ChangeNotifier with ReviewActions {
  ReviewAdministrationController({ReviewRepository? repository})
    : _repository = repository ?? SqlConnectReviewRepository();

  final ReviewRepository _repository;
  final List<Review> _reviews = [];

  @override
  List<Review> get shownReviews => _reviews;
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
    } on ReviewRepositoryException catch (error) {
      _errorMessage = error.message;
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

  Future<String?> toggleVisibility(String reviewId) async {
    final review = findShownReview(reviewId);
    if (review == null) return null;
    final hide = review.status != ReviewModerationStatus.hidden;
    return saveReview(
      reviewId,
      save: () => _repository.setHiddenAsAdmin(reviewId, hidden: hide),
      change: (review) => review.copyWith(
        status: hide
            ? ReviewModerationStatus.hidden
            : ReviewModerationStatus.visible,
      ),
    );
  }

  Future<String?> dismissReport(String reviewId) => saveReview(
    reviewId,
    save: () => _repository.dismissReportAsAdmin(reviewId),
    change: (review) => review.copyWith(
      status: ReviewModerationStatus.visible,
      clearReportReason: true,
    ),
  );

  Future<String?> reply(String reviewId, String message) async {
    final text = message.trim();
    if (text.isEmpty) return null;
    return saveReview(
      reviewId,
      save: () => _repository.replyAsAdmin(reviewId, text),
      change: (review) => review.copyWith(adminReply: text),
    );
  }

  Future<String?> delete(String reviewId) => saveReview(
    reviewId,
    save: () => _repository.delete(reviewId),
    change: (_) => null,
  );
}
