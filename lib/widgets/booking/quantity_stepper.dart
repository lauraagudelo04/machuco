import 'package:flutter/material.dart';

import 'package:machuco/core/design_system/components/app_icon_button.dart';
import 'package:machuco/core/design_system/theme/app_theme_extensions.dart';
import 'package:machuco/core/design_system/tokens/app_spacing.dart';

/// Contador +/- reutilizable con límites mínimo y máximo. Se usa tanto para
/// la cantidad de personas de una reserva como para cualquier otra cantidad
/// acotada (por ejemplo, bloques de horas). Los botones respetan el
/// objetivo táctil mínimo de 48×48px vía [AppIconButton].
class QuantityStepper extends StatelessWidget {
  const QuantityStepper({
    super.key,
    required this.label,
    required this.value,
    required this.max,
    required this.onChanged,
    this.min = 0,
    this.subtitle,
  });

  final String label;
  final String? subtitle;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final canDecrease = value > min;
    final canIncrease = value < max;
    return Semantics(
      label: '$label, $value',
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.bodyLarge),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: context.appColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          AppIconButton(
            icon: Icons.remove,
            tooltip: 'Disminuir $label',
            onPressed: canDecrease ? () => onChanged(value - 1) : null,
          ),
          SizedBox(
            width: AppSpacing.s8,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          AppIconButton(
            icon: Icons.add,
            tooltip: 'Aumentar $label',
            onPressed: canIncrease ? () => onChanged(value + 1) : null,
          ),
        ],
      ),
    );
  }
}
