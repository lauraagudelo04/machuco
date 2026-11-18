import 'package:machuco/models/owner_management/document_type.dart';

/// Tipos de documento de identidad que ofrece el registro público (Cliente y
/// Propietario; decisión 2026-11-17).
///
/// Reutiliza [DocumentType] del módulo de propietarios: `firestore.rules`
/// guarda `users/{uid}.documentType` con [DocumentType.name]. Se excluyen:
/// - [DocumentType.identityCard] (tarjeta de identidad): es de menores de
///   edad y el registro exige ser mayor de 18 años.
/// - [DocumentType.taxId] (NIT): es un dato tributario y el propietario lo
///   indica aparte, en su propio campo.
const registrationDocumentTypes = <DocumentType>[
  DocumentType.citizenshipCard,
  DocumentType.foreignerCard,
  DocumentType.passport,
];

/// Interpreta `users/{uid}.documentType`; `null` si falta o es desconocido.
DocumentType? documentTypeFromStorage(String? value) {
  for (final type in DocumentType.values) {
    if (type.name == value) return type;
  }
  return null;
}
