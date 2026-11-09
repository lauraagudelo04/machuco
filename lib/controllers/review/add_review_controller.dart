import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:machuco/database/repository/review/review_type_repository.dart';
import 'package:machuco/models/review/review.dart';
import 'package:machuco/database/repository/review/review_repository.dart';
import 'package:machuco/service/review/review_author_provider.dart';
import 'package:machuco/service/room/supabase_room_config.dart';
import 'package:machuco/service/storage/local_preferences_service.dart';
import 'package:machuco/service/storage/shared_preferences_local_service.dart';

/// Controlador de reseñas para el cliente.
///
/// Lee y guarda las reseñas a través de [ReviewRepository]; al enviar una
/// reseña nueva desde [AddReviewSheet] se refleja en la UI mediante
/// [ListenableBuilder].
class ReviewsController extends ChangeNotifier {
  ReviewsController({
    LocalPreferencesService? preferences,
    ReviewRepository? repository,
    ReviewAuthorProvider? authorProvider,
    ReviewTypeRepository? typeRepository,
  }) : _preferences =
           preferences ?? SharedPreferencesLocalService(namespace: 'reviews'),
       _repository = repository ?? InMemoryReviewRepository.shared,
       _authorProvider = authorProvider ?? FirebaseReviewAuthorProvider(),
       _typeRepository =
           typeRepository ??
           ReviewTypeRepository(
             baseUrl: SupabaseRoomConfig.baseUrl,
             apiKey: SupabaseRoomConfig.apiKey,
           );

  static const _draftKey = 'addReviewDraft';

  final LocalPreferencesService _preferences;
  final ReviewRepository _repository;
  final ReviewAuthorProvider _authorProvider;
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

  int get visibleCount =>
      _reviews.where((r) => r.status == ReviewModerationStatus.visible).length;

  double get overallAverage => averageRatingOf(_reviews);

  /// Reseñas que el cliente puede ver: las ocultas por el administrador no.
  Iterable<Review> get _publicReviews =>
      _reviews.where((r) => r.status != ReviewModerationStatus.hidden);

  List<Review> getReviewsByMotelId(String motelId) {
    return _publicReviews.where((r) => r.motelId == motelId).toList(growable: false);
  }

  double getAverageByMotelId(String motelId) =>
      averageRatingOf(getReviewsByMotelId(motelId));

  List<Review> getReviewsByRoomId(String roomId) {
    return _publicReviews.where((r) => r.roomId == roomId).toList(growable: false);
  }

  double getAverageByRoomId(String roomId) =>
      averageRatingOf(getReviewsByRoomId(roomId));

  /// Crea y guarda la reseña descrita por [draft].
  ///
  /// Devuelve `false` sin tocar el repositorio ni notificar si la calificación
  /// está fuera de rango, si el título o el texto quedan vacíos al recortar
  /// o si no hay una sesión con autor.
  Future<bool> submitReview(String motelId, ReviewDraft draft) async {
    final title = draft.title.trim();
    final body = draft.body.trim();
    if (!ReviewRules.isValidRating(draft.rating) ||
        !ReviewRules.isValidText(title) ||
        !ReviewRules.isValidText(body)) {
      return false;
    }
    final author = await _authorProvider.currentAuthor();
    if (author == null) return false;

    await addReview(
      Review(
        id: 'review-client-${DateTime.now().millisecondsSinceEpoch}',
        authorId: author.id,
        authorName: author.name,
        title: title,
        body: body,
        rating: draft.rating,
        date: DateTime.now(),
        motelId: motelId,
        roomId: draft.roomId,
        type: draft.type,
        status: ReviewModerationStatus.visible,
      ),
    );
    return true;
  }

  Future<void> addReview(Review review) async {
    await _repository.add(review);
    _reviews.insert(0, review);
    notifyListeners();
    await clearDraft();
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

  Future<void> loadReviews() async {
    final reviews = await _repository.getAll();
    _reviews
      ..clear()
      ..addAll(reviews);
    notifyListeners();
  }
}
