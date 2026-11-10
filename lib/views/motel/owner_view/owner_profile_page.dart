import 'package:flutter/material.dart';

import 'package:machuco/controllers/owner_management/owner_profile_controller.dart';
import 'package:machuco/core/design_system/design_system.dart';
import 'package:machuco/models/auth/account_status.dart';
import 'package:machuco/models/auth/person_type.dart';
import 'package:machuco/models/auth/user_profile.dart';
import 'package:machuco/views/owner_management/owner_summary.dart';

import 'owner_edit_profile_page.dart';

/// Perfil del propietario autenticado (`users/{uid}`).
///
/// Muestra sus datos reales; antes la app no tenía esta vista y el nombre del
/// propietario se veía quemado en la pantalla de moteles.
class OwnerProfilePage extends StatefulWidget {
  const OwnerProfilePage({super.key, this.controller});

  /// Controlador inyectable para los tests; si es `null` se crea uno propio.
  final OwnerProfileController? controller;

  @override
  State<OwnerProfilePage> createState() => _OwnerProfilePageState();
}

class _OwnerProfilePageState extends State<OwnerProfilePage> {
  late final OwnerProfileController _controller;
  late final bool _ownsController;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? OwnerProfileController();
    if (_controller.profile == null) _controller.load();
  }

  @override
  void dispose() {
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  Future<void> _openEdit() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => OwnerEditProfilePage(controller: _controller),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mi perfil')),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) {
            final profile = _controller.profile;

            if (_controller.isLoading && profile == null) {
              return ListView(
                padding: const EdgeInsets.all(AppSpacing.screen),
                children: const [
                  AppSkeleton(height: 180),
                  SizedBox(height: AppSpacing.s6),
                  AppSkeleton(height: 300),
                ],
              );
            }

            if (_controller.errorMessage != null && profile == null) {
              return AppErrorState(
                message: _controller.errorMessage!,
                onRetry: _controller.load,
              );
            }

            if (profile == null) {
              return AppEmptyState(
                icon: Icons.person_off_outlined,
                title: 'Perfil no encontrado',
                message: 'No se encontraron tus datos de propietario.',
                actionLabel: 'Recargar',
                onAction: _controller.load,
              );
            }

            return RefreshIndicator(
              onRefresh: _controller.load,
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.screen),
                children: [
                  _ProfileHeader(profile: profile),
                  const SizedBox(height: AppSpacing.s6),
                  _DetailSection(
                    title: 'Información personal',
                    children: [
                      _InfoRow(
                        icon: Icons.person_outline,
                        label: 'Nombre',
                        value: profile.fullName,
                      ),
                      _InfoRow(
                        icon: Icons.email_outlined,
                        label: 'Correo electrónico',
                        value: profile.email,
                      ),
                      _InfoRow(
                        icon: Icons.phone_outlined,
                        label: 'Teléfono',
                        value: profile.phoneNumber,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.s6),
                  _DetailSection(
                    title: 'Datos legales',
                    children: [
                      _InfoRow(
                        icon: Icons.badge_outlined,
                        label: 'Documento (NIT)',
                        value: profile.nit?.trim().isNotEmpty == true
                            ? profile.nit!
                            : 'Sin documento registrado',
                      ),
                      _InfoRow(
                        icon: Icons.business_outlined,
                        label: 'Tipo de persona',
                        value:
                            profile.personType?.label ?? 'Sin registrar',
                      ),
                      if (profile.companyName != null)
                        _InfoRow(
                          icon: Icons.apartment_outlined,
                          label: 'Razón social',
                          value: profile.companyName!,
                        ),
                      if (profile.planId != null)
                        _InfoRow(
                          icon: Icons.card_membership_outlined,
                          label: 'Plan',
                          value: 'Plan #${profile.planId}',
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.s6),
                  AppButton(
                    label: 'Editar perfil',
                    icon: Icons.edit_outlined,
                    variant: AppButtonVariant.secondary,
                    onPressed: _controller.isSaving ? null : _openEdit,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.profile});

  final UserProfile profile;

  String get _initials {
    final parts = profile.fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return '${parts.first.characters.first}${parts.last.characters.first}'
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final status = profile.accountStatus;
    return AppCard(
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(AppRadius.xl),
            ),
            alignment: Alignment.center,
            child: Text(
              _initials,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.s3),
          Text(
            profile.fullName,
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.s1),
          Text(
            profile.email,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: context.appColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.s3),
          OwnerStatusChip(
            isActive: status == AccountStatus.active,
            status: status,
          ),
        ],
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.s3),
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.s1),
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) const Divider(height: 1),
                children[i],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s4,
        vertical: AppSpacing.s3,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(
              icon,
              size: 20,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: AppSpacing.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: context.appColors.textMuted,
                  ),
                ),
                const SizedBox(height: AppSpacing.s1),
                Text(
                  value,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
