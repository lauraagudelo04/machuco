/// Tipos de documento admitidos para identificar a un propietario.
///
/// Cada valor define cómo se valida el número asociado, para evitar cadenas
/// libres y condicionales dispersos en la interfaz.
enum DocumentType {
  citizenshipCard('CC', 'Cédula de ciudadanía', r'^\d{6,10}$', '1020304050'),
  foreignerCard('CE', 'Cédula de extranjería', r'^\d{6,12}$', '345678'),
  taxId(
    'NIT',
    'Número de identificación tributaria',
    r'^\d{9,10}(-\d)?$',
    '900123456-7',
  ),
  passport('Pasaporte', 'Pasaporte', r'^[A-Za-z0-9]{6,12}$', 'AV123456');

  const DocumentType(
    this.shortLabel,
    this.description,
    this.pattern,
    this.example,
  );

  final String shortLabel;
  final String description;
  final String pattern;
  final String example;

  bool acceptsDocumentNumber(String value) => RegExp(pattern).hasMatch(value);
}
