import 'package:flutter/material.dart';
import 'package:machuco/controllers/auth/admin_access_controller.dart';
import 'package:machuco/controllers/auth/auth_routes.dart';
import 'package:machuco/core/design_system/design_system.dart';
import 'package:machuco/database/repository/auth/admin_access_repository.dart';
import 'package:machuco/models/auth/owner_approval_request.dart';
import 'package:machuco/models/auth/person_type.dart';
import 'package:machuco/views/admin_access/owner_approval_detail_page.dart';
import 'package:machuco/views/admin_access/owner_application_format.dart';

/// Lista de solicitudes de propietarios pendientes (solo administradores).
class OwnerApprovalsPage extends StatefulWidget {
  const OwnerApprovalsPage({super.key, this.controller});

  /// Si es `null` se crea uno sobre Firestore y esta página lo libera.
  final AdminAccessController? controller;

  @override
  State<OwnerApprovalsPage> createState() => _OwnerApprovalsPageState();
}

class _OwnerApprovalsPageState extends State<OwnerApprovalsPage> {
  late final AdminAccessController _controller;
  late final bool _ownsController;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller =
        widget.controller ??
        AdminAccessController(repository: FirestoreAdminAccessRepository());
    _controller.loadPendingOwners();
  }

  @override
  void dispose() {
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  Future<void> _refresh() => _controller.loadPendingOwners();

  void _open(OwnerApplication application) {
    Navigator.of(context).pushNamed(
      AuthRoutes.adminOwnerApprovalDetail,
      arguments: OwnerApprovalDetailArgs(
        uid: application.uid,
        controller: _controller,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Solicitudes de propietarios')),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) {
            final owners = _controller.pendingOwners;
            final Widget body;
            if (_controller.isLoading && owners.isEmpty) {
              body = const _LoadingList();
            } else if (_controller.error != null && owners.isEmpty) {
              body = _ScrollableState(
                child: AppErrorState(
                  message: _controller.error!,
                  onRetry: _refresh,
                ),
              );
            } else if (owners.isEmpty) {
              body = const _ScrollableState(
                child: AppEmptyState(
                  icon: Icons.inbox_outlined,
                  title: 'No hay solicitudes pendientes',
                  message: 'Cuando un propietario se registre, aparecerá aquí.',
                ),
              );
            } else {
              body = ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppSpacing.s4),
                itemCount: owners.length + 1,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: AppSpacing.s3),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return _Counter(count: owners.length);
                  }
                  final application = owners[index - 1];
                  return _ApplicationCard(
                    application: application,
                    onTap: () => _open(application),
                  );
                },
              );
            }
            return RefreshIndicator(onRefresh: _refresh, child: body);
          },
        ),
      ),
    );
  }
}

class _Counter extends StatelessWidget {
  const _Counter({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Text(
        count == 1 ? '1 solicitud pendiente' : '$count solicitudes pendientes',
        style: Theme.of(context).textTheme.titleMedium,
      ),
    );
  }
}

class _ApplicationCard extends StatelessWidget {
  const _ApplicationCard({required this.application, required this.onTap});

  final OwnerApplication application;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: context.appColors.textSecondary,
    );
    return AppCard(
      key: ValueKey('application-${application.uid}'),
      onTap: onTap,
      semanticLabel: 'Solicitud de ${ownerApplicationTitle(application)}',
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ownerApplicationTitle(application),
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.s1),
                Text(
                  application.personType?.label ?? 'Tipo no indicado',
                  style: muted,
                ),
                Text(application.email, style: muted),
                Text(
                  formatApplicationDate(application.createdAt),
                  style: muted,
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

class _LoadingList extends StatelessWidget {
  const _LoadingList();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Cargando solicitudes',
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
