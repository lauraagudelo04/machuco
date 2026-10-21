import 'package:floor/floor.dart';

/// Fila de la tabla `owners`: refleja 1:1 al modelo de dominio `Owner`.
///
/// Floor no almacena booleanos ni enums sin convertidor, así que el estado
/// activo y la marca de sincronización viajan como entero (0/1) y el tipo de
/// documento como su nombre (`DocumentType.name`); el mapeo al modelo de
/// dominio vive en `OwnerRepository`.
@Entity(tableName: 'owners')
class OwnerEntry {
  const OwnerEntry({
    required this.id,
    required this.fullName,
    required this.documentType,
    required this.documentNumber,
    required this.email,
    required this.phone,
    this.address,
    required this.isActive,
    required this.synchronized,
    required this.createdAt,
    required this.updatedAt,
  });

  @PrimaryKey()
  final String id;
  final String fullName;

  /// Nombre del enum de dominio, por ejemplo `citizenshipCard`.
  final String documentType;
  final String documentNumber;
  final String email;
  final String phone;
  final String? address;

  /// 1 = activo, 0 = inactivo.
  final int isActive;

  /// 0 = pendiente de enviar a la nube, 1 = ya sincronizado.
  final int synchronized;
  final DateTime createdAt;
  final DateTime updatedAt;
}
