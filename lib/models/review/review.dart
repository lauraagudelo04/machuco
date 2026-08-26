class Review {
  final String author;
  final String title;
  final String body;
  final int rating;
  final DateTime date;

  const Review({
    required this.author,
    required this.title,
    required this.body,
    required this.rating,
    required this.date,
  });
}