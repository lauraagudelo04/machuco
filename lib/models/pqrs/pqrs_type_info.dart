import 'package:machuco/models/pqrs/pqrs.dart';

/// A PQRS type as the catalog `pqrs_types` describes it. Only [type].name
/// (the `code`) is stored in Firestore; the rest is display data.
class PqrsTypeInfo {
  const PqrsTypeInfo({
    required this.type,
    required this.name,
    required this.description,
    this.responseDays = pqrsDefaultResponseDays,
    this.allowsPhotos = true,
    this.sortOrder = 0,
  });

  final PqrsType type;
  final String name;
  final String description;

  /// Business days to answer (Monday to Friday, holidays not considered).
  final int responseDays;
  final bool allowsPhotos;
  final int sortOrder;

  /// Maps a catalog `code` to the enum by name; null for an unknown code.
  static PqrsType? typeFromCode(String code) {
    for (final type in PqrsType.values) {
      if (type.name == code) return type;
    }
    return null;
  }

  /// The four types with their current labels, used when the catalog has
  /// been neither downloaded nor cached. Same texts as the SQL seed.
  static const List<PqrsTypeInfo> defaults = [
    PqrsTypeInfo(
      type: PqrsType.peticion,
      name: 'Petición',
      description: 'Solicita información o un servicio del motel.',
      sortOrder: 1,
    ),
    PqrsTypeInfo(
      type: PqrsType.queja,
      name: 'Queja',
      description:
          'Expresa tu inconformidad con la atención o el servicio recibido.',
      sortOrder: 2,
    ),
    PqrsTypeInfo(
      type: PqrsType.reclamo,
      name: 'Reclamo',
      description:
          'Reclama por un cobro, un servicio no prestado o un derecho '
          'incumplido.',
      sortOrder: 3,
    ),
    PqrsTypeInfo(
      type: PqrsType.sugerencia,
      name: 'Sugerencia',
      description: 'Propón una mejora para el motel o la plataforma.',
      sortOrder: 4,
    ),
  ];
}

/// Default business days to answer a PQRS.
const pqrsDefaultResponseDays = 15;
