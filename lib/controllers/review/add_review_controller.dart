import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:machuco/models/review/review.dart';
import 'package:machuco/service/storage/local_preferences_service.dart';
import 'package:machuco/service/storage/shared_preferences_local_service.dart';

/// Borrador de una reseña a medio escribir en el formulario.
typedef ReviewDraft = ({String tag, int rating, String title, String body});

/// Controlador de reseñas para el cliente.
///
/// Mantiene una lista mutable de reseñas del cliente para que, al enviar
/// una nueva reseña desde [AddReviewSheet], se refleje inmediatamente en la
/// UI a través de [ListenableBuilder].  En el futuro este controlador
/// delegará en un [ReviewRepository] para persistir en el backend.
class ReviewsController extends ChangeNotifier {
  ReviewsController({LocalPreferencesService? preferences})
    : _preferences =
          preferences ?? SharedPreferencesLocalService(namespace: 'reviews');

  static const _draftKey = 'addReviewDraft';

  final LocalPreferencesService _preferences;

  final List<Review> _reviews = [
    Review(
      parentId: "3",
      author: 'Carlos M.',
      title: 'Muy cómodo y tranquilo',
      body: 'Las habitaciones estaban limpias y el personal fue muy amable. La cama súper cómoda.',
      rating: 5,
      date: DateTime(2026, 7, 20),
      tag: "Motel Eclipse"
    ),
    Review(
      parentId: "3",
      author: 'Luisa P.',
      title: 'Buena ubicación',
      body: 'Está bien ubicado, cerca de todo. El precio es justo para lo que ofrece.',
      rating: 4,
      date: DateTime(2026, 6, 15),
      tag: "Motel Eclipse"
    ),
    Review(
      parentId: "3",
      author: 'Roberto V.',
      title: 'Aceptable',
      body: 'Correcto para una noche. El wifi un poco lento pero el resto bien.',
      rating: 3,
      date: DateTime(2026, 5, 3),
      tag: "Motel Eclipse"
    ),
    Review(
      parentId: "2",
      author: 'Roberto V.',
      title: 'Aceptable',
      body: 'Un poco desorganizada pero el ambiente se sentia bien.',
      rating: 3,
      date: DateTime(2026, 5, 3),
      tag: 'Suite Nova'
    ),
  ];

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
    clearDraft();
  }

  /// Devuelve el borrador guardado para [parentId], o `null` si no hay uno o
  /// pertenece a otro motel.
  Future<ReviewDraft?> loadDraft(String parentId) async {
    try {
      final raw = await _preferences.getString(_draftKey);
      if (raw == null) return null;

      final json = jsonDecode(raw) as Map<String, dynamic>;
      if (json['parentId'] != parentId) return null;

      return (
        tag: json['tag'] as String,
        rating: json['rating'] as int,
        title: json['title'] as String,
        body: json['body'] as String,
      );
    } catch (error) {
      // El borrador es una comodidad: si no se puede leer, el formulario
      // simplemente arranca vacío.
      debugPrint('loadDraft: $error');
      return null;
    }
  }

  Future<void> saveDraft(String parentId, ReviewDraft draft) async {
    try {
      await _preferences.setString(
        _draftKey,
        jsonEncode({
          'parentId': parentId,
          'tag': draft.tag,
          'rating': draft.rating,
          'title': draft.title,
          'body': draft.body,
        }),
      );
    } catch (error) {
      debugPrint('saveDraft: $error');
    }
  }

  Future<void> clearDraft() async {
    try {
      await _preferences.remove(_draftKey);
    } catch (error) {
      debugPrint('clearDraft: $error');
    }
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