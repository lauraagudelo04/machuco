import 'package:flutter/material.dart';
import 'package:machuco/controllers/auth/administrators_controller.dart';
import 'package:machuco/controllers/auth/auth_routes.dart';
import 'package:machuco/core/design_system/design_system.dart';
import 'package:machuco/models/auth/user_profile.dart';
import 'package:machuco/views/admin_access/administrator_detail_page.dart';
import 'package:machuco/views/admin_access/administrator_format.dart';
import 'package:machuco/views/admin_access/administrators_factory.dart';

/// Lista de administradores (solo administradores; el guard de la ruta es UX,
/// la autorización real son las reglas de Firestore).
class AdministratorsPage extends StatefulWidget {
  const AdministratorsPage({super.key, this.controller, this.currentUid});

  /// Si es `null` se crea el de producción y esta página lo libera.
  final AdministratorsController? controller;

  /// Uid propio para la etiqueta "Tú". Si es `null` se lee de la sesión.
  final String? currentUid;

  @override
  State<AdministratorsPage> createState() => _AdministratorsPageState();
}

class _AdministratorsPageState extends State<AdministratorsPage> {
  late final AdministratorsController _controller;
  late final bool _ownsController;
  late final String? _currentUid;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? buildAdministratorsController();
    _currentUid = widget.currentUid ?? currentAdminUid();
    _controller.load();
  }

  @override
  void dispose() {
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  Future<void> _refresh() => _controller.load();

  Future<void> _create() async {
    final created = await Navigator.of(context).pushNamed<Object?>(
      AuthRoutes.adminCreateAdministrator,
      arguments: _controller,
    );
    if (created != true || !mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Administrador creado.')));
  }

  void _open(UserProfile profile) {
    Navigator.of(context).pushNamed(
      AuthRoutes.adminAdministratorDetail,
      arguments: AdministratorDetailArgs(
        uid: profile.uid,
        controller: _controller,
        currentUid: _currentUid,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Administradores')),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) {
            final admins = _controller.administrators;
            final Widget body;
            if (_controller.isLoading && admins.isEmpty) {
              body = const _LoadingList();
            } else if (_controller.error != null && admins.isEmpty) {
              body = _ScrollableState(
                child: AppErrorState(
                  message: _controller.error!,
                  onRetry: _refresh,
                ),
              );
            } else if (admins.isEmpty) {
              body = const _ScrollableState(
                child: AppEmptyState(
                  icon: Icons.admin_panel_settings_outlined,
                  title: 'No hay administradores',
                  message: 'Crea el primer administrador para empezar.',
                ),
              );
            } else {
              body = ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppSpacing.s4),
                itemCount: admins.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: AppSpacing.s3),
                itemBuilder: (context, index) {
                  final profile = admins[index];
                  return _AdministratorCard(
                    profile: profile,
                    isMe: profile.uid == _currentUid,
                    onTap: () => _open(profile),
                  );
                },
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.s4,
                    AppSpacing.s4,
                    AppSpacing.s4,
                    0,
                  ),
                  child: AppButton(
                    label: 'Crear administrador',
                    icon: Icons.person_add_alt_1_outlined,
                    onPressed: _create,
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(onRefresh: _refresh, child: body),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _AdministratorCard extends StatelessWidget {
  const _AdministratorCard({
    required this.profile,
    required this.isMe,
    required this.onTap,
  });

  final UserProfile profile;
  final bool isMe;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: context.appColors.textSecondary,
    );
    return AppCard(
      key: ValueKey('administrator-${profile.uid}'),
      onTap: onTap,
      semanticLabel: 'Administrador ${profile.fullName}',
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: AppSpacing.s2,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      profile.fullName,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (isMe) const _MeBadge(),
                  ],
                ),
                const SizedBox(height: AppSpacing.s1),
                Text(profile.email, style: muted),
                const SizedBox(height: AppSpacing.s1),
                Row(
                  children: [
                    Icon(
                      administratorStatusIcon(profile),
                      size: AppSpacing.s4,
                      color: muted?.color,
                    ),
                    const SizedBox(width: AppSpacing.s1),
                    Expanded(
                      child: Text(
                        administratorStatusLabel(profile),
                        style: muted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right),
        ],
      ),
    );
  }
}

class _MeBadge extends StatelessWidget {
  const _MeBadge();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.appColors.elevated,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: theme.colorScheme.primary),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s2,
          vertical: AppSpacing.s1,
        ),
        child: Text(
          'Tú',
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.primary,
          ),
        ),
      ),
    );
  }
}

class _LoadingList extends StatelessWidget {
  const _LoadingList();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Cargando administradores',
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.s4),
        children: [
          for (var i = 0; i < 3; i++) ...[
            const AppSkeleton(
              width: double.infinity,
              height: AppSpacing.s12 + AppSpacing.s8,
            ),
            const SizedBox(height: AppSpacing.s3),
          ],
        ],
      ),
    );
  }
}

/// Permite el pull to refresh también en los estados vacío y de error.
class _ScrollableState extends StatelessWidget {
  const _ScrollableState({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(child: child),
        ),
      ),
    );
  }
}
