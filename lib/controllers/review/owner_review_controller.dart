import 'package:flutter/foundation.dart';
import 'package:machuco/controllers/motel/motel_controller.dart';
import 'package:machuco/models/motel/motel_model.dart';
import 'package:machuco/models/review/review.dart';
import 'package:machuco/models/review/review_type.dart';

/// Reseña vista desde la perspectiva del propietario: envuelve un [Review]
/// y lo asocia a un motel suyo. El modelo Review compartido todavía no
/// tiene una relación real con Motel, así que esa asociación vive aquí
/// (composición), no en el modelo.
class OwnerReviewEntry {
  OwnerReviewEntry({
    required this.review,
    required this.motelId,
    required this.motelName,
    this.ownerReply,
  });

  final Review review;
  final String motelId;
  final String motelName;
  String? ownerReply;
}

class OwnerReviewController extends ChangeNotifier {
  OwnerReviewController({MotelController? motelController})
    : _motelController = motelController ?? MotelController();

  static final OwnerReviewController instance = OwnerReviewController();

  final MotelController _motelController;

  List<Motel> _myMotels = [];
  List<OwnerReviewEntry> _entries = [];
  String? _selectedMotelId; // null = todos mis moteles
  String _query = '';
  bool _isLoading = false;
  String? _errorMessage;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<Motel> get myMotels => List.unmodifiable(_myMotels);
  String? get selectedMotelId => _selectedMotelId;
  String get query => _query;

  /// TODO: reemplazar por la carga real de reseñas cuando Review incluya
  /// una relación con el motel (motelId).
  Future<void> loadReviews() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _myMotels = await _motelController.getMyMotels();
      if (_entries.isEmpty) {
        _entries = _seedEntries(_myMotels);
      }
    } catch (_) {
      _errorMessage = 'No fue posible cargar las reseñas de tus moteles.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  List<OwnerReviewEntry> get entries {
    final normalizedQuery = _query.trim().toLowerCase();
    return _entries.where((entry) {
      if (_selectedMotelId != null && entry.motelId != _selectedMotelId) {
        return false;
      }
      if (normalizedQuery.isEmpty) return true;
      return entry.review.author.toLowerCase().contains(normalizedQuery) ||
          entry.review.title.toLowerCase().contains(normalizedQuery) ||
          entry.review.body.toLowerCase().contains(normalizedQuery);
    }).toList(growable: false);
  }

  int get totalCount => entries.length;

  double get averageRating {
    final visible = entries;
    if (visible.isEmpty) return 0;
    return visible.map((e) => e.review.rating).reduce((a, b) => a + b) /
        visible.length;
  }

  void selectMotel(String? motelId) {
    _selectedMotelId = motelId;
    notifyListeners();
  }

  void setQuery(String query) {
    _query = query;
    notifyListeners();
  }

  void reply(OwnerReviewEntry entry, String message) {
    final trimmed = message.trim();
    if (trimmed.isEmpty) return;
    entry.ownerReply = trimmed;
    notifyListeners();
  }

  List<OwnerReviewEntry> _seedEntries(List<Motel> myMotels) {
    if (myMotels.isEmpty) return [];
    final first = myMotels.first;
    final second = myMotels.length > 1 ? myMotels[1] : myMotels.first;
    return [
      OwnerReviewEntry(
        review: Review(
          author: 'Diana R.',
          title: 'Excelente atención',
          body:
              'El personal fue muy amable y la habitación estaba impecable.',
          rating: 5,
          date: DateTime(2026, 7, 10),
          type: ReviewType.motel,
        ),
        motelId: first.id,
        motelName: first.name,
      ),
      OwnerReviewEntry(
        review: Review(
          author: 'Felipe A.',
          title: 'El aire acondicionado no enfriaba',
          body: 'Todo bien excepto el aire, que casi no funcionaba.',
          rating: 3,
          date: DateTime(2026, 7, 28),
          type: ReviewType.room,
        ),
        motelId: second.id,
        motelName: second.name,
      ),
    ];
  }
}