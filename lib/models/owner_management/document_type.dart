/// Tipos de documento admitidos para identificar a un propietario.
///
/// Cada valor define cómo se valida el número asociado, para evitar cadenas
/// libres y condicionales dispersos en la interfaz. El maestro persistido
/// (`document_types`) usa [code] para mapear sus filas a este enum.
enum DocumentType {
  citizenshipCard(
    'CC',
    'CC',
    'Cédula de ciudadanía',
    r'^\d{6,10}$',
    '1020304050',
  ),
  foreignerCard('CE', 'CE', 'Cédula de extranjería', r'^\d{6,12}$', '345678'),
  taxId(
    'NIT',
    'NIT',
    'Número de identificación tributaria',
    r'^\d{9,10}(-\d)?$',
    '900123456-7',
  ),
  passport('PAS', 'Pasaporte', 'Pasaporte', r'^[A-Za-z0-9]{6,12}$', 'AV123456'),
  identityCard('TI', 'TI', 'Tarjeta de identidad', r'^\d{6,11}$', '1020304050');

  const DocumentType(
    this.code,
    this.shortLabel,
    this.description,
    this.pattern,
    this.example,
  );

  /// Código estable que usan la nube y el maestro (`CC`, `CE`, `NIT`...).
  final String code;

  final String shortLabel;
  final String description;
  final String pattern;
  final String example;

  bool acceptsDocumentNumber(String value) => RegExp(pattern).hasMatch(value);

  /// Resuelve un [code] del maestro; devuelve `null` si ya no existe en el
  /// dominio (por ejemplo, un tipo retirado en una versión futura).
  static DocumentType? fromCode(String code) {
    for (final type in DocumentType.values) {
      if (type.code == code) return type;
    }
    return null;
  }
}
