import 'package:machuco/models/review/review_type.dart';

class Review {
  final String author;
  final String title;
  final String body;
  final int rating;
  final DateTime date;
  final ReviewType type;

  const Review({
    required this.author,
    required this.title,
    required this.body,
    required this.rating,
    required this.date,
    required this.type,
  });
}