import 'package:flutter/material.dart';
import 'package:machuco/core/design_system/design_system.dart';
import 'package:machuco/models/auth/auth_provider_kind.dart';

/// "Continuar con Google" y "Continuar con GitHub".
///
/// Mientras [busyProvider] no es `null`, ese botón muestra carga y ambos
/// quedan deshabilitados (un segundo toque no abre otro flujo). Si
/// [onSelected] es `null` (Firebase no disponible en esta compilación) los
/// botones se deshabilitan con una explicación.
class SocialAuthButtons extends StatelessWidget {
  const SocialAuthButtons({
    super.key,
    required this.onSelected,
    this.busyProvider,
    this.enabled = true,
  });

  static const providers = [AuthProviderKind.google, AuthProviderKind.github];

  final ValueChanged<AuthProviderKind>? onSelected;
  final AuthProviderKind? busyProvider;

  /// `false` mientras otra operación del formulario está en curso.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final available = onSelected != null;
    final idle = busyProvider == null && enabled;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final provider in providers) ...[
          AppButton(
            key: ValueKey('social-${provider.name}'),
            label: 'Continuar con ${provider.displayName}',
            variant: AppButtonVariant.secondary,
            loading: busyProvider == provider,
            onPressed: available && idle ? () => onSelected!(provider) : null,
          ),
          const SizedBox(height: AppSpacing.s3),
        ],
        if (!available)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.s3),
            child: Text(
              'El ingreso con Google y GitHub no está disponible en esta '
              'versión.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: context.appColors.textMuted,
              ),
            ),
          ),
      ],
    );
  }
}
