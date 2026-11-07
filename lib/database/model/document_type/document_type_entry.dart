import 'package:floor/floor.dart';

/// Fila del maestro `document_types`: los tipos de documento que puede
/// seleccionar el formulario de propietarios.
///
/// El dominio sigue usando el enum `DocumentType`; [code] es la llave estable
/// que conecta cada fila con su valor del enum.
@Entity(tableName: 'document_types')
class DocumentTypeEntry {
  const DocumentTypeEntry({
    required this.id,
    required this.code,
    required this.name,
    required this.pattern,
    required this.example,
    required this.isActive,
    required this.sortOrder,
  });

  @PrimaryKey()
  final int id;

  /// Código estable: `CC`, `CE`, `NIT`, `PAS`, `TI`.
  final String code;

  /// Nombre legible que se muestra en el selector.
  final String name;

  /// Expresión regular con la que se valida el número.
  final String pattern;

  /// Ejemplo de número para la ayuda del formulario.
  final String example;

  /// 1 = disponible, 0 = retirado (no se ofrece en formularios nuevos).
  final int isActive;
  final int sortOrder;
}
