import 'package:flutter/material.dart';

import 'package:machuco/core/design_system/theme/app_theme_extensions.dart';
import 'package:machuco/core/design_system/tokens/app_spacing.dart';

/// Fila seleccionable (casilla) para un servicio adicional o un producto
/// opcional dentro del formulario de reserva: nombre, detalle corto y
/// precio formateado. Reutilizable en cualquier lista de "extras"
/// opcionales con precio.
class PricedCheckboxTile extends StatelessWidget {
  const PricedCheckboxTile({
    super.key,
    required this.title,
    required this.priceLabel,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.enabled = true,
  });

  final String title;
  final String? subtitle;
  final String priceLabel;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final disabledColor = context.appColors.textDisabled;
    return Semantics(
      button: true,
      toggled: value,
      enabled: enabled,
      label: '$title, $priceLabel',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? () => onChanged(!value) : null,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.s1),
              child: Row(
                children: [
                  Checkbox(
                    value: value,
                    onChanged: enabled
                        ? (checked) => onChanged(checked ?? false)
                        : null,
                  ),
                  const SizedBox(width: AppSpacing.s1),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(color: enabled ? null : disabledColor),
                        ),
                        if (subtitle != null)
                          Text(
                            subtitle!,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: context.appColors.textSecondary,
                                ),
                          ),
                      ],
                    ),
                  ),
                  Text(
                    priceLabel,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: enabled
                          ? Theme.of(context).colorScheme.primary
                          : disabledColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
