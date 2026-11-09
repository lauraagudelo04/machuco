/// Tipo de persona del propietario ante la DIAN.
///
/// Se guarda en `users/{uid}.personType` con [metadataValue].
enum PersonType { natural, juridica }

extension PersonTypeValue on PersonType {
  String get metadataValue => switch (this) {
    PersonType.natural => 'natural',
    PersonType.juridica => 'juridica',
  };

  /// Texto visible en español.
  String get label => switch (this) {
    PersonType.natural => 'Persona natural',
    PersonType.juridica => 'Persona jurídica',
  };
}

/// Interpreta el valor almacenado; `null` si falta o es desconocido (no se
/// asume un tipo por omisión).
PersonType? personTypeFromMetadata(String? value) {
  return switch (value?.trim().toLowerCase()) {
    'natural' => PersonType.natural,
    'juridica' => PersonType.juridica,
    _ => null,
  };
}
