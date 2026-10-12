/// Tipo de reseña según qué elemento del motel se está evaluando.
enum ReviewType {
  motel('Motel'),
  room('Habitación');

  final String label;
  const ReviewType(this.label);

  static ReviewType fromString(String value) {
    return ReviewType.values.firstWhere(
      (type) => type.name == value.toLowerCase(),
      orElse: () => ReviewType.motel,
    );
  }
}

/// Estado de moderación asignado por el administrador a una reseña.
enum ReviewModerationStatus {
  visible,
  hidden,
  reported,
}

extension ReviewModerationStatusData on ReviewModerationStatus {
  String get label => switch (this) {
    ReviewModerationStatus.visible => 'Visible',
    ReviewModerationStatus.hidden => 'Oculta',
    ReviewModerationStatus.reported => 'Reportada',
  };
}

/// Una reseña de un cliente a un motel o habitación.
///
/// Reemplaza a los wrappers [AdminReviewEntry] y [OwnerReviewEntry]: todos los
/// campos de moderación, respuesta y relación con el motel viven aquí como
/// propiedades del dominio.
class Review {
  final String id;            // id propio para integridad referencial
  final String authorId;      // referencia al usuario (autor de la reseña)
  final String authorName;    // nombre visible (se pinta en la UI)
  final String title;
  final String body;
  final int rating;           // 1-5
  final DateTime date;

  // Relación con el dominio de moteles/habitaciones
  final String motelId;
  final String? roomId;       // null = reseña del motel, no de habitación

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
  Review copyWith({
    ReviewModerationStatus? status,
    String? reportReason,
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
      reportReason: reportReason ?? this.reportReason,
      adminReply: adminReply ?? this.adminReply,
      ownerReply: ownerReply ?? this.ownerReply,
    );
  }
}