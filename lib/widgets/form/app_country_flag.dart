import 'package:country_flags/country_flags.dart';
import 'package:flutter/material.dart';
import 'package:machuco/core/design_system/design_system.dart';

/// Bandera de un país a partir de su código ISO 3166-1 alfa-2 (p. ej. `CO`).
///
/// Envuelve `country_flags` con los tokens del design system para que
/// cualquier funcionalidad la reutilice sin conocer la librería. La bandera
/// es decorativa: el nombre del país o el indicativo deben mostrarse al lado.
/// Un código desconocido no lanza error; la librería pinta un recuadro vacío.
class AppCountryFlag extends StatelessWidget {
  const AppCountryFlag({
    super.key,
    required this.isoCode,
    this.width = AppSpacing.s6,
    this.height = AppSpacing.s4,
  });

  final String isoCode;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: CountryFlag.fromCountryCode(
        isoCode,
        theme: ImageTheme(
          width: width,
          height: height,
          shape: const RoundedRectangle(AppRadius.sm / 2),
        ),
      ),
    );
  }
}
