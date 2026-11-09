import 'package:flutter/material.dart';
import 'package:machuco/core/design_system/design_system.dart';

/// Hoja inferior tematizada con título, desplazable y que respeta el teclado.
///
/// Es genérica: recibe el contenido por [builder] y no conoce ningún dominio.
abstract final class AppBottomSheet {
  static Future<T?> show<T>(
    BuildContext context, {
    required String title,
    required WidgetBuilder builder,
    bool isDismissible = true,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      isDismissible: isDismissible,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: AppSpacing.screen,
            right: AppSpacing.screen,
            bottom:
                MediaQuery.viewInsetsOf(sheetContext).bottom + AppSpacing.s4,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    title,
                    style: Theme.of(sheetContext).textTheme.titleMedium,
                  ),
                ),
                const SizedBox(height: AppSpacing.s3),
                Builder(builder: builder),
              ],
            ),
          ),
        );
      },
    );
  }
}
