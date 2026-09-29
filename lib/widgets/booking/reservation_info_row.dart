import 'package:flutter/material.dart';

import 'package:machuco/core/design_system/theme/app_theme_extensions.dart';
import 'package:machuco/core/design_system/tokens/app_spacing.dart';

/// Fila "icono + etiqueta + valor" para pantallas de detalle (icono a la
/// izquierda, etiqueta expandida al centro y valor alineado a la derecha).
///
/// Extraído del patrón `_InfoRow` que ya existía duplicado como widget
/// privado en `lib/views/booking/client_view/reservation_detail_page.dart`.
/// Esa vista de Cliente no se modifica aquí (fuera de alcance de esta
/// tarea); queda como nota pendiente para el equipo migrarla a este widget
/// compartido más adelante sin cambiar su comportamiento visual.
class ReservationInfoRow extends StatelessWidget {
  const ReservationInfoRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: context.appColors.textSecondary),
        const SizedBox(width: AppSpacing.s3),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: context.appColors.textSecondary,
            ),
          ),
        ),
        Flexible(
          child: Text(
            value,
            style: Theme.of(context).textTheme.titleSmall,
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
}
