import 'package:flutter/material.dart';

import 'package:machuco/controllers/auth/user_profile_controller.dart';
import 'package:machuco/core/design_system/design_system.dart';
import 'package:machuco/models/auth/account_status.dart';
import 'package:machuco/models/auth/user_profile.dart';
import 'package:machuco/views/auth/change_password_page.dart';
import 'package:machuco/views/auth/user_edit_profile_page.dart';
import 'package:machuco/widgets/account_status_chip.dart';
import 'package:machuco/widgets/auth/auth_notice.dart';

/// Perfil del administrador autenticado (`users/{uid}`).
///
/// Muestra sus datos reales y permite editar nombre y teléfono (lo único que
/// `firestore.rules` deja autoeditar a un administrador activo) además de
/// cambiar su contraseña.
class AdminProfilePage extends StatefulWidget {
  const AdminProfilePage({super.key, this.controller});

  /// Controlador inyectable para los tests; si es `null` se crea uno propio.
  final UserProfileController? controller;

  @override
  State<AdminProfilePage> createState() => _AdminProfilePageState();
}

class _AdminProfilePageState extends State<AdminProfilePage> {
  late final UserProfileController _controller;
  late final bool _ownsController;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? UserProfileController();
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
        builder: (context) => UserEditProfilePage(controller: _controller),
      ),
    );
  }

  Future<void> _openChangePassword() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => ChangePasswordPage(controller: _controller),
      ),
    );
    if (changed == true && mounted) await _controller.load();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final profile = _controller.profile;
        // Las reglas exigen un administrador ACTIVO para editar sus datos; con
        // contraseña temporal pendiente (`mustChangePassword`) no se permite.
        final mustChangePassword = profile?.mustChangePassword == true;
        return Scaffold(
          appBar: AppBar(title: const Text('Mi perfil')),
          body: SafeArea(child: _buildBody(profile)),
          bottomNavigationBar: profile == null
              ? null
              : _AdminProfileActions(
                  onEdit: mustChangePassword || _controller.isSaving
                      ? null
                      : _openEdit,
                  onChangePassword: _controller.isChangingPassword
                      ? null
                      : _openChangePassword,
                ),
        );
      },
    );
  }

  Widget _buildBody(UserProfile? profile) {
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
        message: 'No se encontraron los datos de tu cuenta.',
        actionLabel: 'Recargar',
        onAction: _controller.load,
      );
    }

    return RefreshIndicator(
      onRefresh: _controller.load,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.screen),
        children: [
          _AdminHeader(profile: profile),
          const SizedBox(height: AppSpacing.s6),
          _DetailSection(
            title: 'Información de la cuenta',
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
              _InfoRow(
                icon: Icons.admin_panel_settings_outlined,
                label: 'Rol',
                value: 'Administrador',
              ),
            ],
          ),
          if (profile.mustChangePassword) ...[
            const SizedBox(height: AppSpacing.s6),
            const AuthNotice(
              message:
                  'Estás usando una contraseña temporal. Cámbiala para poder '
                  'editar los datos de tu cuenta.',
              tone: AuthNoticeTone.info,
            ),
          ],
        ],
      ),
    );
  }
}

class _AdminProfileActions extends StatelessWidget {
  const _AdminProfileActions({
    required this.onEdit,
    required this.onChangePassword,
  });

  final VoidCallback? onEdit;
  final VoidCallback? onChangePassword;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.appColors.canvas,
        border: Border(top: BorderSide(color: context.appColors.border)),
      ),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.all(AppSpacing.s4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppButton(
              label: 'Editar perfil',
              icon: Icons.edit_outlined,
              variant: AppButtonVariant.secondary,
              size: AppButtonSize.medium,
              onPressed: onEdit,
            ),
            const SizedBox(height: AppSpacing.s2),
            AppButton(
              label: 'Cambiar contraseña',
              icon: Icons.lock_outline,
              size: AppButtonSize.medium,
              onPressed: onChangePassword,
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminHeader extends StatelessWidget {
  const _AdminHeader({required this.profile});

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
          AccountStatusChip(
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
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
