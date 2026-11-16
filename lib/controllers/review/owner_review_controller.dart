import 'package:flutter/foundation.dart';
import 'package:machuco/controllers/motel/motel_controller.dart';
import 'package:machuco/models/motel/motel_model.dart';
import 'package:machuco/models/review/review.dart';
// Prefijo aparte: el getter [averageRating] tapa el nombre de la función de
// dominio del mismo nombre dentro de la clase.
import 'package:machuco/database/repository/review/firestore_review_repository.dart';
import 'package:machuco/database/repository/review/review_repository.dart';
import 'package:machuco/database/repository/review/sql_connect_review_repository.dart';

/// Controlador de reseñas desde la perspectiva del propietario.
///
/// Opera directamente sobre el modelo [Review]; la asociación con el motel
/// se resuelve a través de [motelId] que ahora vive en el modelo.
class OwnerReviewController extends ChangeNotifier {
  OwnerReviewController({
    MotelController? motelController,
    ReviewRepository? repository,
  }) : _motelController = motelController ?? MotelController(),
       _repository = repository ?? SqlConnectReviewRepository();

  final MotelController _motelController;
  final ReviewRepository _repository;

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
      final motelIds = _myMotels.map((m) => m.id).toSet();
      _reviews = (await _repository.getAll())
          .where((r) => motelIds.contains(r.motelId))
          .toList();
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

  /// Guarda la respuesta del propietario a [reviewId].
  ///
  /// Devuelve `null` si se guardó (o si no había nada que guardar) y el
  /// motivo en texto si el servidor la rechazó; en ese caso la reseña no
  /// cambia en pantalla.
  Future<String?> reply(String reviewId, String message) async {
    final trimmed = message.trim();
    final index = _reviews.indexWhere((r) => r.id == reviewId);
    if (trimmed.isEmpty || index == -1) return null;
    try {
      await _repository.replyAsOwner(reviewId, trimmed);
    } on ReviewRepositoryException catch (error) {
      return error.message;
    }
    _reviews[index] = _reviews[index].copyWith(ownerReply: trimmed);
    notifyListeners();
    return null;
  }

  /// Nombre del motel, o su [motelId] si no está entre los del propietario.
  String getMotelName(String motelId) {
    for (final motel in _myMotels) {
      if (motel.id == motelId) return motel.name;
    }
    return motelId;
  }
}
