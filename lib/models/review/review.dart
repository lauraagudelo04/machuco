/// Tipo de reseña según qué elemento del motel se está evaluando.
///
/// [id] coincide con la tabla `review_types` de Supabase; [label] es el nombre
/// local que se usa mientras no se haya consultado la tabla.
enum ReviewType {
  room(1, 'Habitación'),
  motel(2, 'Motel'),
  attention(3, 'Atención');

  final int id;
  final String label;
  const ReviewType(this.id, this.label);

  static ReviewType fromString(String value) {
    return ReviewType.values.firstWhere(
      (type) => type.name == value.toLowerCase(),
      orElse: () => ReviewType.motel,
    );
  }

  /// Devuelve el tipo con [id], o `null` si la app aún no lo conoce.
  static ReviewType? fromId(int id) {
    for (final type in ReviewType.values) {
      if (type.id == id) return type;
    }
    return null;
  }
}

/// Opción del selector de tipo de reseña: el tipo y el nombre a mostrar.
typedef ReviewTypeOption = ({ReviewType type, String name});

/// Estado de moderación asignado por el administrador a una reseña.
enum ReviewModerationStatus { visible, hidden, reported }

extension ReviewModerationStatusData on ReviewModerationStatus {
  String get label => switch (this) {
    ReviewModerationStatus.visible => 'Visible',
    ReviewModerationStatus.hidden => 'Oculta',
    ReviewModerationStatus.reported => 'Reportada',
  };
}

/// Borrador de una reseña a medio escribir en el formulario.
///
/// Vive en el dominio para que la vista y el controlador compartan la misma
/// forma de datos sin depender entre sí.
typedef ReviewDraft = ({
  ReviewType type,
  String? roomId,
  int rating,
  String title,
  String body,
});

/// Una reseña de un cliente a un motel o habitación.
///
/// Reemplaza a los wrappers [AdminReviewEntry] y [OwnerReviewEntry]: todos los
/// campos de moderación, respuesta y relación con el motel viven aquí como
/// propiedades del dominio.
class Review {
  final String id; // id propio para integridad referencial
  final String authorId; // referencia al usuario (autor de la reseña)
  final String authorName; // nombre visible (se pinta en la UI)
  final String title;
  final String body;
  final int rating; // 1-5
  final DateTime date;

  // Relación con el dominio de moteles/habitaciones
  final String motelId;
  final String? roomId; // null = reseña del motel, no de habitación

  // Tipo de reseña (reconecta el enum ReviewType)
  final ReviewType type;

  // Moderación y respuestas
  final ReviewModerationStatus status;
  final String? reportReason;
  final String? adminReply;
  final String? ownerReply;

  const Review({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.title,
    required this.body,
    required this.rating,
    required this.date,
    required this.motelId,
    this.roomId,
    this.type = ReviewType.motel,
    this.status = ReviewModerationStatus.visible,
    this.reportReason,
    this.adminReply,
    this.ownerReply,
  });

  /// Copia inmutable con campos actualizados.
  ///
  /// Pasar `null` no borra un campo opcional; para quitar el motivo del
  /// reporte usa [clearReportReason].
  Review copyWith({
    ReviewModerationStatus? status,
    String? reportReason,
    bool clearReportReason = false,
    String? adminReply,
    String? ownerReply,
  }) {
    return Review(
      id: id,
      authorId: authorId,
      authorName: authorName,
      title: title,
      body: body,
      rating: rating,
      date: date,
      motelId: motelId,
      roomId: roomId,
      type: type,
      status: status ?? this.status,
      reportReason: clearReportReason
          ? null
          : reportReason ?? this.reportReason,
      adminReply: adminReply ?? this.adminReply,
      ownerReply: ownerReply ?? this.ownerReply,
    );
  }
}

/// Promedio de calificaciones de [reviews], o `0` si la colección está vacía.
///
/// Único lugar donde vive el cálculo: los controladores de cliente,
/// propietario y administrador lo reutilizan para no duplicar la regla.
double averageRatingOf(Iterable<Review> reviews) {
  var total = 0;
  var count = 0;
  for (final review in reviews) {
    total += review.rating;
    count++;
  }
  return count == 0 ? 0 : total / count;
}

/// Reglas de validación del dominio de reseñas.
///
/// Las usan la vista (para mostrar errores) y el controlador (para rechazar
/// envíos inválidos), de modo que ambas coincidan siempre.
abstract final class ReviewRules {
  static const minRating = 1;
  static const maxRating = 5;

  static bool isValidRating(int rating) =>
      rating >= minRating && rating <= maxRating;

  static bool isValidText(String text) => text.trim().isNotEmpty;
}
