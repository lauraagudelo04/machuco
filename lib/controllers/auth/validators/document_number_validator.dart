import 'package:machuco/controllers/auth/validators/auth_input_normalizer.dart';
import 'package:machuco/models/auth/document_type.dart';

/// Valida el número de documento con el `pattern` del tipo elegido en el
/// maestro `document_types`.
///
/// Es un filtro de UX y de formato: la autoridad es `firestore.rules`. El
/// valor es texto plano; nunca se interpola en consultas.
abstract final class DocumentNumberValidator {
  /// Validación básica cuando no hay tipo o su regex no compila: alfanumérico
  /// de 4 a 20 caracteres.
  static final _basic = RegExp(r'^[A-Za-z0-9]{4,20}$');

  static const emptyMessage = 'Ingresa tu número de documento.';

  /// `null` si [value] es válido para [type]. Recorta los espacios y aplica el
  /// patrón sobre el número tal como se escribió y ya normalizado (sin
  /// puntos ni guiones, en mayúsculas), que es como se guarda. Un patrón
  /// inválido no lanza: cae a la validación básica.
  static String? validate(String? value, DocumentTypeOption? type) {
    final trimmed = (value ?? '').trim();
    if (trimmed.isEmpty) return emptyMessage;
    final normalized = AuthInputNormalizer.documentNumber(trimmed);
    final regex = _compile(type?.pattern);
    final valid = regex == null
        ? _basic.hasMatch(normalized)
        : regex.hasMatch(trimmed) || regex.hasMatch(normalized);
    if (valid) return null;
    final example = type?.example;
    return example == null
        ? 'Ingresa un documento válido (4 a 20 letras o números).'
        : 'Número no válido. Ejemplo: $example.';
  }

  /// Validador para un `TextFormField`.
  static String? Function(String?) forType(DocumentTypeOption? type) =>
      (value) => validate(value, type);

  static RegExp? _compile(String? pattern) {
    if (pattern == null || pattern.isEmpty) return null;
    try {
      return RegExp(pattern);
    } on FormatException {
      return null;
    }
  }
}
