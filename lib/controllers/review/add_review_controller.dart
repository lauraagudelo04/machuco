import 'package:flutter/material.dart';
import 'package:machuco/models/review/review.dart';
import 'package:machuco/models/review/review_data.dart';

/// Controlador de reseñas para el cliente.
///
/// Mantiene una lista mutable de reseñas del cliente para que, al enviar
/// una nueva reseña desde [AddReviewSheet], se refleje inmediatamente en la
/// UI a través de [ListenableBuilder].  En el futuro este controlador
/// delegará en un [ReviewRepository] para persistir en el backend.
class ReviewsController extends ChangeNotifier {
  final List<Review> _reviews = [];

  int get totalCount => _reviews.length;

  int get visibleCount => _reviews
      .where((r) => r.status == ReviewModerationStatus.visible)
      .length;

  double get overallAverage => _reviews.isEmpty
      ? 0.0
      : _reviews.map((r) => r.rating).reduce((a, b) => a + b) /
          _reviews.length;

  List<Review> getReviewsByMotelId(String motelId) {
    return _reviews
        .where((r) => r.motelId == motelId)
        .toList(growable: false);
  }

  double getAverageByMotelId(String motelId) {
    final filtered = getReviewsByMotelId(motelId);
    if (filtered.isEmpty) return 0.0;
    final total = filtered.map((r) => r.rating).reduce((a, b) => a + b);
    return total / filtered.length;
  }

  List<Review> getReviewsByRoomId(String roomId) {
    return _reviews
        .where((r) => r.roomId == roomId)
        .toList(growable: false);
  }

  double getAverageByRoomId(String roomId) {
    final filtered = getReviewsByRoomId(roomId);
    if (filtered.isEmpty) return 0.0;
    final total = filtered.map((r) => r.rating).reduce((a, b) => a + b);
    return total / filtered.length;
  }

  void addReview(Review review) {
    _reviews.insert(0, review);
    notifyListeners();
  }

  /// TODO: reemplazar por carga desde el backend cuando el repositorio
  /// de reseñas esté disponible.
  void seedReviews() {
    if (_reviews.isEmpty) {
      _reviews.addAll(ReviewData.all());
      notifyListeners();
    }
  }
}