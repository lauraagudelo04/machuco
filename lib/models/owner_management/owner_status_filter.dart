import 'package:machuco/models/owner_management/owner.dart';

/// Filtro por estado aplicable al listado de propietarios.
///
/// Cada valor sabe qué propietarios admite, para que la vista solo elija el
/// filtro y no repita la condición en cada punto donde se usa.
enum OwnerStatusFilter {
  all('Todos'),
  active('Activos'),
  inactive('Inactivos');

  const OwnerStatusFilter(this.label);

  /// Texto que identifica al filtro en la interfaz.
  final String label;

  bool matches(Owner owner) => switch (this) {
    OwnerStatusFilter.all => true,
    OwnerStatusFilter.active => owner.isActive,
    OwnerStatusFilter.inactive => !owner.isActive,
  };
}
