import 'package:flutter/material.dart';
import 'package:machuco/core/design_system/design_system.dart';

/// Accesos "Continuar con Google" y "Continuar con GitHub": deshabilitados y
/// sin lógica hasta que se implementen (se rotulan "Próximamente").
class ComingSoonSocialButtons extends StatelessWidget {
  const ComingSoonSocialButtons({super.key});

  static const providers = ['Google', 'GitHub'];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final provider in providers) ...[
          Semantics(
            label: 'Continuar con $provider, próximamente',
            excludeSemantics: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppButton(
                  label: 'Continuar con $provider',
                  variant: AppButtonVariant.secondary,
                  onPressed: null,
                ),
                const SizedBox(height: AppSpacing.s1),
                Text(
                  'Próximamente',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.appColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.s3),
        ],
      ],
    );
  }
}
