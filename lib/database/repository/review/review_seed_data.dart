import 'package:machuco/models/review/review.dart';

/// Reseñas de ejemplo con las que arranca [InMemoryReviewRepository].
///
/// Solo el repositorio en memoria las usa; los controladores nunca las leen
/// directamente.
List<Review> reviewSeedData() => [
    // --- Admin ---
    Review(
      id: 'review-1',
      authorId: 'user-carlos',
      authorName: 'Carlos M.',
      title: 'Muy cómodo y tranquilo',
      body:
          'Las habitaciones estaban limpias y el personal fue muy amable.',
      rating: 5,
      date: DateTime(2026, 7, 20),
      motelId: '3',
      type: ReviewType.motel,
    ),
    Review(
      id: 'review-2',
      authorId: 'user-roberto',
      authorName: 'Roberto V.',
      title: 'Comentario inapropiado',
      body:
          'Contiene lenguaje ofensivo y datos personales expuestos.',
      rating: 1,
      date: DateTime(2026, 8, 2),
      motelId: '3',
      type: ReviewType.motel,
      status: ReviewModerationStatus.reported,
      reportReason:
          'Lenguaje inapropiado y datos personales expuestos',
    ),
    // --- Owner ---
    Review(
      id: 'review-owner-1',
      authorId: 'user-diana',
      authorName: 'Diana R.',
      title: 'Excelente atención',
      body:
          'El personal fue muy amable y la habitación estaba impecable.',
      rating: 5,
      date: DateTime(2026, 7, 10),
      motelId: '1',
      type: ReviewType.motel,
    ),
    Review(
      id: 'review-owner-2',
      authorId: 'user-felipe',
      authorName: 'Felipe A.',
      title: 'El aire acondicionado no enfriaba',
      body:
          'Todo bien excepto el aire, que casi no funcionaba.',
      rating: 3,
      date: DateTime(2026, 7, 28),
      motelId: '2',
      type: ReviewType.motel,
    ),
    // --- Client (motel detail) ---
    Review(
      id: 'review-client-1',
      authorId: 'user-anonymous-1',
      authorName: 'Laura G.',
      title: 'Gran experiencia',
      body:
          'Superó las expectativas. Volveremos sin duda.',
      rating: 5,
      date: DateTime(2026, 8, 15),
      motelId: '3',
      type: ReviewType.room,
    ),
    Review(
      id: 'review-client-2',
      authorId: 'user-anonymous-2',
      authorName: 'Miguel T.',
      title: 'OK, pero mejorable',
      body:
          'La ubicación es buena, pero el desayuno podría mejorar.',
      rating: 3,
      date: DateTime(2026, 8, 20),
      motelId: '3',
      type: ReviewType.motel,
    ),
];
