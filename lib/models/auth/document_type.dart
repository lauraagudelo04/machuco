import 'package:machuco/database/model/document_type/document_type_entry.dart';
import 'package:machuco/models/auth/identity_document.dart';
import 'package:machuco/models/owner_management/document_type.dart';

/// Tipo de documento de identidad ofrecido en el registro, tal como lo publica
/// el maestro `document_types` de Supabase (`id`, `code`, `name`, `pattern`,
/// `example`, `sort_order`).
///
/// No es el enum [DocumentType] del módulo de propietarios: este modelo trae el
/// patrón y el ejemplo del maestro; [domainType] lo conecta con el enum, cuyo
/// `name` es lo único que acepta `users/{uid}.documentType` en
/// `firestore.rules`.
class DocumentTypeOption {
  const DocumentTypeOption({
    required this.id,
    required this.code,
    required this.name,
    required this.pattern,
    required this.example,
    this.sortOrder = 0,
  });

  /// Desde el maestro de Supabase. `null` si falta algún campo de texto.
  static DocumentTypeOption? tryFromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final code = _text(json['code']);
    final name = _text(json['name']);
    final pattern = json['pattern']?.toString();
    final example = _text(json['example']);
    if (id is! int ||
        code == null ||
        name == null ||
        pattern == null ||
        pattern.isEmpty ||
        example == null) {
      return null;
    }
    final order = json['sort_order'];
    return DocumentTypeOption(
      id: id,
      code: code,
      name: name,
      pattern: pattern,
      example: example,
      sortOrder: order is int ? order : 0,
    );
  }

  /// Desde la fila ya guardada en SQLite (DAO compartido `document_types`).
  factory DocumentTypeOption.fromEntry(DocumentTypeEntry entry) =>
      DocumentTypeOption(
        id: entry.id,
        code: entry.code,
        name: entry.name,
        pattern: entry.pattern,
        example: entry.example,
        sortOrder: entry.sortOrder,
      );

  /// Opción con los valores del enum (semilla local sin maestro).
  factory DocumentTypeOption.fromDomain(DocumentType type, {int? id}) =>
      DocumentTypeOption(
        id: id ?? type.index + 1,
        code: type.code,
        name: type.description,
        pattern: type.pattern,
        example: type.example,
        sortOrder: type.index,
      );

  final int id;

  /// Código estable: `CC`, `CE`, `PAS`...
  final String code;
  final String name;

  /// Expresión regular del número.
  final String pattern;
  final String example;
  final int sortOrder;

  /// Valor del enum que guardan las reglas, o `null` si el código no existe en
  /// el dominio.
  DocumentType? get domainType => DocumentType.fromCode(code);

  /// `true` si el registro público ofrece este tipo (CC, CE y pasaporte).
  bool get isOfferedInRegistration =>
      domainType != null && registrationDocumentTypes.contains(domainType);

  static String? _text(Object? raw) {
    final value = raw?.toString().trim() ?? '';
    return value.isEmpty ? null : value;
  }

  @override
  bool operator ==(Object other) =>
      other is DocumentTypeOption &&
      other.id == id &&
      other.code == code &&
      other.name == name &&
      other.pattern == pattern &&
      other.example == example;

  @override
  int get hashCode => Object.hash(id, code, name, pattern, example);
}
