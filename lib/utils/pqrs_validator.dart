/// Client-side validation of the PQRS forms.
///
/// This only gives fast feedback to the user. The real validation lives in the
/// Firestore rules (Stage 3); until they exist, these checks SIMULATE the
/// backend limits and never replace them.
abstract final class PqrsValidator {
  static const subjectMinLength = 3;
  static const subjectMaxLength = 100;
  static const descriptionMinLength = 10;
  static const descriptionMaxLength = 1000;
  static const messageMinLength = 1;
  static const messageMaxLength = 1000;
  static const rejectReasonMinLength = 10;

  /// Default photo limit; the real one comes from `pqrs_settings.max_photos`.
  static const defaultMaxPhotos = 3;

  /// Upper bound the Firestore rules accept per entry, whatever Supabase says.
  static const hardMaxPhotos = 10;

  static const motelRequiredMessage = 'Selecciona un motel';
  static const typeRequiredMessage = 'Selecciona un tipo de solicitud';

  /// Returns an error message, or `null` when [value] is valid.
  static String? subject(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return 'El asunto es obligatorio';
    if (text.length < subjectMinLength || text.length > subjectMaxLength) {
      return 'El asunto debe tener entre $subjectMinLength y '
          '$subjectMaxLength caracteres';
    }
    return null;
  }

  static String? description(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return 'La descripción es obligatoria';
    if (text.length < descriptionMinLength ||
        text.length > descriptionMaxLength) {
      return 'La descripción debe tener entre $descriptionMinLength y '
          '$descriptionMaxLength caracteres';
    }
    return null;
  }

  /// Progress message of the owner or comment of the client.
  static String? message(String? value) {
    final text = (value ?? '').trim();
    if (text.length < messageMinLength) return 'El mensaje es obligatorio';
    if (text.length > messageMaxLength) {
      return 'El mensaje no puede superar $messageMaxLength caracteres';
    }
    return null;
  }

  static String? rejectReason(String? value) {
    final text = (value ?? '').trim();
    if (text.length < rejectReasonMinLength) {
      return 'La justificación del rechazo debe tener al menos '
          '$rejectReasonMinLength caracteres';
    }
    if (text.length > messageMaxLength) {
      return 'La justificación no puede superar $messageMaxLength caracteres';
    }
    return null;
  }

  static String? photoCount(int count, {int max = defaultMaxPhotos}) =>
      count > max ? 'Puedes adjuntar máximo $max fotos' : null;
}
