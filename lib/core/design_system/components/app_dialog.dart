import 'package:flutter/material.dart';

import '../theme/app_theme_extensions.dart';
import '../tokens/app_radius.dart';
import '../tokens/app_spacing.dart';

/// Diálogo de confirmación genérico y tematizado (Material 3), para
/// acciones que requieren una confirmación explícita antes de ejecutarse
/// (p. ej. cancelar una reserva). No asume ningún dominio concreto: solo
/// presenta título/mensaje y dos botones, devolviendo si el usuario
/// confirmó o no.
///
/// Nota: este componente no existía todavía en `core/design_system`
/// aunque aparece listado en el catálogo mínimo de referencia; se agrega
/// aquí porque el flujo de cancelación de reservas lo requiere de forma
/// explícita y varias pantallas del proyecto pueden reutilizarlo.
abstract final class AppDialog {
  /// Muestra el diálogo y devuelve `true` solo si el usuario presiona el
  /// botón de confirmación; `false` en cualquier otro caso (cancelar,
  /// cerrar tocando fuera, back button, etc.).
  static Future<bool> confirm(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'Confirmar',
    String cancelLabel = 'Cancelar',
    bool destructive = false,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Theme.of(dialogContext).colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        title: Text(title),
        content: Text(
          message,
          style: Theme.of(dialogContext).textTheme.bodyMedium?.copyWith(
            color: dialogContext.appColors.textSecondary,
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(
          AppSpacing.s4,
          0,
          AppSpacing.s4,
          AppSpacing.s4,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
            child: Text(cancelLabel),
          ),
          FilledButton(
            style: destructive
                ? FilledButton.styleFrom(
                    backgroundColor: Theme.of(dialogContext).colorScheme.error,
                    minimumSize: const Size(48, 48),
                  )
                : FilledButton.styleFrom(minimumSize: const Size(48, 48)),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }
}
