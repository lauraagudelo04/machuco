import 'package:machuco/models/review/review.dart';

/// Fuente compartida de datos mock para el módulo de reseñas.
///
/// Los tres controladores (administración, propietario y cliente) deben
/// consumir sus datos de aquí para evitar islas de información. Cuando
/// el backend esté listo, este archivo se reemplaza por una llamada a
/// [ReviewRepository] (pendiente de decisión del equipo).
class ReviewData {
  /// Todas las reseñas mock (sin filtrar).
  static List<Review> all() => [
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
      motelId: 'motel-eclipse',
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
      motelId: 'motel-eclipse',
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
      motelId: 'motel-sol',
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
      motelId: 'motel-luna',
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
      motelId: 'motel-eclipse',
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
      motelId: 'motel-eclipse',
      type: ReviewType.motel,
    ),
  ];

  /// Reseñas filtradas por motel.
  static List<Review> byMotelId(String motelId) =>
      all().where((r) => r.motelId == motelId).toList();

  /// Promedio de rating para un motel.
  static double averageForMotelId(String motelId) {
    final reviews = byMotelId(motelId);
    if (reviews.isEmpty) return 0;
    return reviews
            .map((r) => r.rating)
            .reduce((a, b) => a + b) /
        reviews.length;
  }
}