/// Normalización de datos de formularios de autenticación, aplicada ANTES de
/// validar y de enviar. Centralizada para que controllers y servicios no
/// dupliquen la lógica.
abstract final class AuthInputNormalizer {
  /// Correo sin espacios en los extremos y en minúsculas.
  static String email(String? value) => (value ?? '').trim().toLowerCase();

  /// Nombres/apellidos/razón social: recorta los extremos.
  static String text(String? value) => (value ?? '').trim();

  /// Deja solo los dígitos.
  static String digits(String? value) =>
      (value ?? '').replaceAll(RegExp(r'\D'), '');

  /// NIT canónico `base-DV` (p. ej. `900123456-8`), o `null` si no tiene una
  /// forma numérica reconocible. No comprueba el dígito de verificación.
  static String? nit(String? value) {
    final raw = (value ?? '').trim();
    final match = RegExp(r'^(\d+)-(\d)$').firstMatch(raw);
    if (match != null) {
      return '${match.group(1)}-${match.group(2)}';
    }
    if (RegExp(r'^\d{2,}$').hasMatch(raw)) {
      return '${raw.substring(0, raw.length - 1)}-${raw.substring(raw.length - 1)}';
    }
    return null;
  }
}
