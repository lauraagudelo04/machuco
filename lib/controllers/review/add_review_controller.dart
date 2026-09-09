import 'package:flutter/material.dart';
import 'package:machuco/models/review/review.dart';
import 'package:machuco/models/review/review_type.dart';

class ReviewsController extends ChangeNotifier {
  final List<Review> _reviews = [
    Review(
      author: 'Carlos M.',
      title: 'Muy cómodo y tranquilo',
      body: 'Las habitaciones estaban limpias y el personal fue muy amable. La cama súper cómoda.',
      rating: 5,
      date: DateTime(2026, 7, 20),
      type: ReviewType.motel
    ),
    Review(
      author: 'Luisa P.',
      title: 'Buena ubicación',
      body: 'Está bien ubicado, cerca de todo. El precio es justo para lo que ofrece.',
      rating: 4,
      date: DateTime(2026, 6, 15),
      type: ReviewType.motel
    ),
    Review(
      author: 'Roberto V.',
      title: 'Aceptable',
      body: 'Correcto para una noche. El wifi un poco lento pero el resto bien.',
      rating: 3,
      date: DateTime(2026, 5, 3),
      type: ReviewType.motel
    ),
    Review(
      author: 'Roberto V.',
      title: 'Aceptable',
      body: 'Un poco desorganizada pero el ambiente se sentia bien.',
      rating: 3,
      date: DateTime(2026, 5, 3),
      type: ReviewType.room
    ),
  ];

  List<Review> getReviewsByType(ReviewType type) {
    return _reviews.where((review) => review.type == type).toList();
  }

  double getAverageByType(ReviewType type) {
    final filtered = getReviewsByType(type);
    if (filtered.isEmpty) return 0.0;
    
    final total = filtered.map((r) => r.rating).reduce((a, b) => a + b);
    return total / filtered.length;
  }

  void addReview(Review review) {
    _reviews.insert(0, review);
    notifyListeners();
  }
}