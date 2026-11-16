import 'package:flutter/foundation.dart';
import 'package:machuco/controllers/motel/motel_controller.dart';
import 'package:machuco/controllers/review/review_actions.dart';
import 'package:machuco/models/motel/motel_model.dart';
import 'package:machuco/models/review/review.dart';
// Prefijo aparte: el getter [averageRating] tapa el nombre de la función de
// dominio del mismo nombre dentro de la clase.
import 'package:machuco/database/repository/review/review_repository.dart';
import 'package:machuco/database/repository/review/sql_connect_review_repository.dart';

/// Controlador de reseñas desde la perspectiva del propietario.
///
/// Opera directamente sobre el modelo [Review]; la asociación con el motel
/// se resuelve a través de [motelId] que ahora vive en el modelo.
class OwnerReviewController extends ChangeNotifier with ReviewActions {
  OwnerReviewController({
    MotelController? motelController,
    ReviewRepository? repository,
  }) : _motelController = motelController ?? MotelController(),
       _repository = repository ?? SqlConnectReviewRepository();

  final MotelController _motelController;
  final ReviewRepository _repository;

  List<Motel> _myMotels = [];
  List<Review> _reviews = [];

  @override
  List<Review> get shownReviews => _reviews;
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
      final motelIds = _myMotels.map((m) => m.id).toSet();
      _reviews = (await _repository.getAll())
          .where((r) => motelIds.contains(r.motelId))
          .toList();
    } on ReviewRepositoryException catch (error) {
      _errorMessage = error.message;
    } catch (_) {
      _errorMessage = 'No fue posible cargar las reseñas de tus moteles.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  List<Review> get reviews {
    final normalizedQuery = _query.trim().toLowerCase();
    return _reviews
        .where((review) {
          if (_selectedMotelId != null && review.motelId != _selectedMotelId) {
            return false;
          }
          if (normalizedQuery.isEmpty) return true;
          return review.authorName.toLowerCase().contains(normalizedQuery) ||
              review.title.toLowerCase().contains(normalizedQuery) ||
              review.body.toLowerCase().contains(normalizedQuery);
        })
        .toList(growable: false);
  }

  int get totalCount => reviews.length;

  double get averageRating => averageRatingOf(reviews);

  void selectMotel(String? motelId) {
    _selectedMotelId = motelId;
    notifyListeners();
  }

  void setQuery(String query) {
    _query = query;
    notifyListeners();
  }

  Future<String?> reply(String reviewId, String message) async {
    final text = message.trim();
    if (text.isEmpty) return null;
    return saveReview(
      reviewId,
      save: () => _repository.replyAsOwner(reviewId, text),
      change: (review) => review.copyWith(ownerReply: text),
    );
  }

  /// Envía la reseña a revisión del administrador con el motivo [reason].
  Future<String?> report(String reviewId, String reason) async {
    final text = reason.trim();
    if (text.isEmpty) return null;
    return saveReview(
      reviewId,
      save: () => _repository.reportAsOwner(reviewId, text),
      change: (review) => review.copyWith(
        status: ReviewModerationStatus.reported,
        reportReason: text,
      ),
    );
  }

  /// Nombre del motel, o su [motelId] si no está entre los del propietario.
  String getMotelName(String motelId) {
    for (final motel in _myMotels) {
      if (motel.id == motelId) return motel.name;
    }
    return motelId;
  }
}
