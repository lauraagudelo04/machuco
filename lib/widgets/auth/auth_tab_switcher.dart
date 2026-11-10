import 'package:flutter/material.dart';
import 'package:machuco/core/design_system/design_system.dart';

enum AuthTab { login, register }

/// Selector de pestañas "Iniciar sesión / Registrarse".
class AuthTabSwitcher extends StatelessWidget {
  const AuthTabSwitcher({
    super.key,
    required this.selectedTab,
    required this.onChanged,
  });

  final AuthTab selectedTab;
  final ValueChanged<AuthTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: context.appColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: _AuthTabButton(
              text: 'Iniciar sesión',
              selected: selectedTab == AuthTab.login,
              onTap: () => onChanged(AuthTab.login),
            ),
          ),
          Expanded(
            child: _AuthTabButton(
              text: 'Registrarse',
              selected: selectedTab == AuthTab.register,
              onTap: () => onChanged(AuthTab.register),
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthTabButton extends StatelessWidget {
  const _AuthTabButton({
    required this.text,
    required this.selected,
    required this.onTap,
  });

  final String text;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textColor = selected ? Colors.white : context.appColors.textSecondary;
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppMotion.fast,
          curve: AppMotion.standard,
          constraints: const BoxConstraints(minHeight: 48),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            gradient: selected ? AppGradients.primary : null,
          ),
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.s3,
            horizontal: AppSpacing.s3,
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
