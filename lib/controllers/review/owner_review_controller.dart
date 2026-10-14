import 'package:flutter/foundation.dart';
import 'package:machuco/controllers/motel/motel_controller.dart';
import 'package:machuco/models/motel/motel_model.dart';
import 'package:machuco/models/review/review.dart';
import 'package:machuco/models/review/review_data.dart';

/// Controlador de reseñas desde la perspectiva del propietario.
///
/// Opera directamente sobre el modelo [Review]; la asociación con el motel
/// se resuelve a través de [motelId] que ahora vive en el modelo.
class OwnerReviewController extends ChangeNotifier {
  OwnerReviewController({MotelController? motelController})
    : _motelController = motelController ?? MotelController();

  final MotelController _motelController;

  List<Motel> _myMotels = [];
  List<Review> _reviews = [];
  String? _selectedMotelId; // null = todos mis moteles
  String _query = '';
  bool _isLoading = false;
  String? _errorMessage;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<Motel> get myMotels => List.unmodifiable(_myMotels);
  String? get selectedMotelId => _selectedMotelId;
  String get query => _query;

  Future<void> loadReviews() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _myMotels = await _motelController.getMyMotels();
      if (_reviews.isEmpty) {
        // Filtrar reseñas que pertenezcan a los moteles del propietario
        final motelIds = _myMotels.map((m) => m.id).toSet();
        _reviews = ReviewData.all()
            .where((r) => motelIds.contains(r.motelId))
            .toList();
      }
    } catch (_) {
      _errorMessage = 'No fue posible cargar las reseñas de tus moteles.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  List<Review> get reviews {
    final normalizedQuery = _query.trim().toLowerCase();
    return _reviews.where((review) {
      if (_selectedMotelId != null && review.motelId != _selectedMotelId) {
        return false;
      }
      if (normalizedQuery.isEmpty) return true;
      return review.authorName.toLowerCase().contains(normalizedQuery) ||
          review.title.toLowerCase().contains(normalizedQuery) ||
          review.body.toLowerCase().contains(normalizedQuery);
    }).toList(growable: false);
  }

  int get totalCount => reviews.length;

  double get averageRating {
    if (reviews.isEmpty) return 0;
    return reviews.map((r) => r.rating).reduce((a, b) => a + b) /
        reviews.length;
  }

  void selectMotel(String? motelId) {
    _selectedMotelId = motelId;
    notifyListeners();
  }

  void setQuery(String query) {
    _query = query;
    notifyListeners();
  }

  void reply(String reviewId, String message) {
    final trimmed = message.trim();
    if (trimmed.isEmpty) return;
    final review = _reviews.firstWhere((r) => r.id == reviewId);
    _reviews[_reviews.indexOf(review)] =
        review.copyWith(ownerReply: trimmed);
    notifyListeners();
  }

  String getMotelName(String motelId) =>
      _myMotels.firstWhere((m) => m.id == motelId, orElse: () => _myMotels.first).name;
}