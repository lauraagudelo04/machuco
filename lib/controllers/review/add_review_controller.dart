import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:machuco/database/repository/review/review_type_repository.dart';
import 'package:machuco/models/review/review.dart';
import 'package:machuco/models/review/review_data.dart';
import 'package:machuco/service/room/supabase_room_config.dart';
import 'package:machuco/service/storage/local_preferences_service.dart';
import 'package:machuco/service/storage/shared_preferences_local_service.dart';

/// Borrador de una reseña a medio escribir en el formulario.
typedef ReviewDraft = ({
  ReviewType type,
  String? roomId,
  int rating,
  String title,
  String body,
});

/// Controlador de reseñas para el cliente.
///
/// Mantiene una lista mutable de reseñas del cliente para que, al enviar
/// una nueva reseña desde [AddReviewSheet], se refleje inmediatamente en la
/// UI a través de [ListenableBuilder].  En el futuro este controlador
/// delegará en un [ReviewRepository] para persistir en el backend.
class ReviewsController extends ChangeNotifier {
  ReviewsController({
    LocalPreferencesService? preferences,
    ReviewTypeRepository? typeRepository,
  }) : _preferences =
           preferences ?? SharedPreferencesLocalService(namespace: 'reviews'),
       _typeRepository =
           typeRepository ??
           ReviewTypeRepository(
             baseUrl: SupabaseRoomConfig.baseUrl,
             apiKey: SupabaseRoomConfig.apiKey,
           );

  static const _draftKey = 'addReviewDraft';

  final LocalPreferencesService _preferences;
  final ReviewTypeRepository _typeRepository;

  final List<Review> _reviews = [];

  List<ReviewTypeOption>? _reviewTypes;

  /// Tipos de reseña de Supabase. Se consultan una sola vez por controller.
  ///
  /// Lanza [ReviewTypeRepositoryException] si no se pudieron obtener.
  Future<List<ReviewTypeOption>> loadReviewTypes() async {
    return _reviewTypes ??= await _typeRepository.getReviewTypes();
  }

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

  /// Devuelve el borrador guardado para [motelId], o `null` si no hay uno o
  /// pertenece a otro motel.
  Future<ReviewDraft?> loadDraft(String motelId) async {
    try {
      final raw = await _preferences.getString(_draftKey);
      if (raw == null) return null;

      final json = jsonDecode(raw) as Map<String, dynamic>;
      if (json['motelId'] != motelId) return null;

      return (
        type: ReviewType.fromString(json['type'] as String),
        roomId: json['roomId'] as String?,
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

  Future<void> saveDraft(String motelId, ReviewDraft draft) async {
    try {
      await _preferences.setString(
        _draftKey,
        jsonEncode({
          'motelId': motelId,
          'type': draft.type.name,
          'roomId': draft.roomId,
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