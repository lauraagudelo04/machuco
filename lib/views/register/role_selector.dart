import 'package:flutter/material.dart';
import 'package:machuco/core/design_system/design_system.dart';
import 'package:machuco/models/auth/registered_user.dart';

/// Tarjetas seleccionables Cliente / Propietario.
///
/// El registro público no ofrece Administrador: solo otro administrador puede
/// crearlo (ver `firestore.rules`).
class RoleSelector extends StatelessWidget {
  const RoleSelector({
    super.key,
    required this.selectedRole,
    required this.onSelected,
  });

  final RegisteredUserRole selectedRole;
  final ValueChanged<RegisteredUserRole> onSelected;

  static const _options =
      <
        ({
          RegisteredUserRole role,
          IconData icon,
          String title,
          String subtitle,
        })
      >[
        (
          role: RegisteredUserRole.client,
          icon: Icons.person_rounded,
          title: 'Cliente',
          subtitle: 'Realiza y consulta reservas',
        ),
        (
          role: RegisteredUserRole.owner,
          icon: Icons.home_work_rounded,
          title: 'Propietario',
          subtitle: 'Gestiona sus propiedades',
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final cards = [
      for (final option in _options)
        _RoleCard(
          key: ValueKey('role-${option.role.name}'),
          icon: option.icon,
          title: option.title,
          subtitle: option.subtitle,
          selected: option.role == selectedRole,
          onTap: () => onSelected(option.role),
        ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 340) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              cards.first,
              const SizedBox(height: AppSpacing.s2),
              cards.last,
            ],
          );
        }
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: cards.first),
              const SizedBox(width: AppSpacing.s2),
              Expanded(child: cards.last),
            ],
          ),
        );
      },
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      selected: selected,
      onTap: onTap,
      semanticLabel: title,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            selected ? Icons.check_circle : icon,
            color: selected
                ? theme.colorScheme.primary
                : context.appColors.textSecondary,
          ),
          const SizedBox(height: AppSpacing.s2),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.s1),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: context.appColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
