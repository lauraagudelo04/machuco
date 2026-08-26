import 'package:flutter/material.dart';
import 'package:machuco/models/review/review.dart';

class ReviewsController extends ChangeNotifier {
  final List<Review> _reviews = [
    Review(
      author: 'Carlos M.',
      title: 'Muy cómodo y tranquilo',
      body: 'Las habitaciones estaban limpias y el personal fue muy amable. La cama súper cómoda.',
      rating: 5,
      date: DateTime(2026, 7, 20),
    ),
    Review(
      author: 'Luisa P.',
      title: 'Buena ubicación',
      body: 'Está bien ubicado, cerca de todo. El precio es justo para lo que ofrece.',
      rating: 4,
      date: DateTime(2026, 6, 15),
    ),
    Review(
      author: 'Roberto V.',
      title: 'Aceptable',
      body: 'Correcto para una noche. El wifi un poco lento pero el resto bien.',
      rating: 3,
      date: DateTime(2026, 5, 3),
    ),
  ];

  List<Review> get reviews => List.unmodifiable(_reviews);

  double get average => _reviews.isEmpty
      ? 0
      : _reviews.map((r) => r.rating).reduce((a, b) => a + b) / _reviews.length;

  void addReview(Review review) {
    _reviews.insert(0, review);
    notifyListeners();
  }
}