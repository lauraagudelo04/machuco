import 'package:flutter/foundation.dart';
import 'package:machuco/models/review/review.dart';

/// Estado de moderación asignado por el administrador a una reseña.
enum ReviewModerationStatus { visible, hidden, reported }

extension ReviewModerationStatusData on ReviewModerationStatus {
  String get label => switch (this) {
    ReviewModerationStatus.visible => 'Visible',
    ReviewModerationStatus.hidden => 'Oculta',
    ReviewModerationStatus.reported => 'Reportada',
  };
}

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

class AdminReviewEntry {
  AdminReviewEntry({
    required this.review,
    this.status = ReviewModerationStatus.visible,
    this.reportReason,
    this.adminReply,
  });

  final Review review;
  ReviewModerationStatus status;
  String? reportReason;
  String? adminReply;
}

class ReviewAdministrationController extends ChangeNotifier {
  ReviewAdministrationController();

  static final ReviewAdministrationController instance =
      ReviewAdministrationController();

  List<AdminReviewEntry> _entries = [];
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
      if (_entries.isEmpty) {
        _entries = _seedEntries();
      }
    } catch (_) {
      _errorMessage = 'No fue posible cargar las reseñas.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  List<AdminReviewEntry> get entries {
    final normalizedQuery = _query.trim().toLowerCase();
    return _entries.where((entry) {
      final matchesFilter = switch (_filter) {
        ReviewFilter.all => true,
        ReviewFilter.visible =>
          entry.status == ReviewModerationStatus.visible,
        ReviewFilter.hidden => entry.status == ReviewModerationStatus.hidden,
        ReviewFilter.reported =>
          entry.status == ReviewModerationStatus.reported,
      };
      if (!matchesFilter) return false;
      if (normalizedQuery.isEmpty) return true;
      return entry.review.author.toLowerCase().contains(normalizedQuery) ||
          entry.review.title.toLowerCase().contains(normalizedQuery) ||
          entry.review.body.toLowerCase().contains(normalizedQuery);
    }).toList(growable: false);
  }

  int get totalCount => _entries.length;

  int get reportedCount => _entries
      .where((e) => e.status == ReviewModerationStatus.reported)
      .length;

  double get averageRating => _entries.isEmpty
      ? 0
      : _entries.map((e) => e.review.rating).reduce((a, b) => a + b) /
            _entries.length;

  void setFilter(ReviewFilter filter) {
    _filter = filter;
    notifyListeners();
  }

  void setQuery(String query) {
    _query = query;
    notifyListeners();
  }

  void toggleVisibility(AdminReviewEntry entry) {
    entry.status = entry.status == ReviewModerationStatus.hidden
        ? ReviewModerationStatus.visible
        : ReviewModerationStatus.hidden;
    notifyListeners();
  }

  void dismissReport(AdminReviewEntry entry) {
    entry.status = ReviewModerationStatus.visible;
    entry.reportReason = null;
    notifyListeners();
  }

  void reply(AdminReviewEntry entry, String message) {
    final trimmed = message.trim();
    if (trimmed.isEmpty) return;
    entry.adminReply = trimmed;
    notifyListeners();
  }

  void delete(AdminReviewEntry entry) {
    _entries.removeWhere((e) => e.review == entry.review);
    notifyListeners();
  }

  List<AdminReviewEntry> _seedEntries() => [
    AdminReviewEntry(
      review: Review(
        author: 'Carlos M.',
        title: 'Muy cómodo y tranquilo',
        body:
            'Las habitaciones estaban limpias y el personal fue muy amable.',
        rating: 5,
        date: DateTime(2026, 7, 20),
      ),
    ),
    AdminReviewEntry(
      review: Review(
        author: 'Roberto V.',
        title: 'Comentario inapropiado',
        body: 'Contiene lenguaje ofensivo y datos personales expuestos.',
        rating: 1,
        date: DateTime(2026, 8, 2),
      ),
      status: ReviewModerationStatus.reported,
      reportReason: 'Lenguaje inapropiado y datos personales expuestos',
    ),
  ];
}