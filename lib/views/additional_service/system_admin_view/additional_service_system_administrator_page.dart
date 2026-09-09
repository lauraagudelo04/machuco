import 'dart:async';

import 'package:flutter/material.dart';
import 'package:machuco/controllers/additional_service/system_admin_view/additional_service_system_administrator_controller.dart';
import 'package:machuco/core/design_system/design_system.dart';
import 'package:machuco/models/additional_service/additional_service.dart';
import 'package:machuco/views/additional_service/system_admin_view/additional_service_admin_form_page.dart';

const _serviceIconExtent = 52.0;
const _serviceIconSize = 26.0;

class AdditionalServiceSystemAdministratorPage extends StatefulWidget {
  const AdditionalServiceSystemAdministratorPage({super.key, this.controller});

  final AdditionalServiceSystemAdministratorController? controller;

  @override
  State<AdditionalServiceSystemAdministratorPage> createState() =>
      _AdditionalServiceSystemAdministratorPageState();
}

class _AdditionalServiceSystemAdministratorPageState
    extends State<AdditionalServiceSystemAdministratorPage> {
  final TextEditingController _searchController = TextEditingController();

  late final AdditionalServiceSystemAdministratorController _controller;
  bool _controllerInitialized = false;

  List<AdditionalService> get _filteredServices =>
      _controller.search(_searchController.text);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controllerInitialized) return;
    final routeArgument = ModalRoute.of(context)?.settings.arguments;
    _controller =
        widget.controller ??
        AdditionalServiceSystemAdministratorController(
          motelId: routeArgument is String
              ? routeArgument
              : AdditionalServiceSystemAdministratorController.demoMotelId,
        );
    _controllerInitialized = true;
    _controller.addListener(_refresh);
    unawaited(_controller.loadServicesByMotelId());
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {});
  }

  Future<void> _confirmDelete(AdditionalService service) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar servicio'),
        content: Text(
          '¿Estás seguro de que deseas eliminar “${service.name}”? Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Sí, eliminar'),
          ),
        ],
      ),
    );
    if (!mounted || shouldDelete != true) return;
    _controller.delete(service);
  }

  @override
  void dispose() {
    if (_controllerInitialized) _controller.removeListener(_refresh);
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Servicios adicionales')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: _buildBody(context),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_controller.isLoading) {
      return ListView(
        padding: const EdgeInsets.all(AppSpacing.screen),
        children: const [
          AppSkeleton(height: 32),
          SizedBox(height: AppSpacing.s3),
          AppSkeleton(height: 20),
          SizedBox(height: AppSpacing.s5),
          AppSkeleton(height: 96),
          SizedBox(height: AppSpacing.s5),
          AppSkeleton(height: 56),
          SizedBox(height: AppSpacing.s6),
          AppSkeleton(height: 148),
        ],
      );
    }

    final errorMessage = _controller.errorMessage;
    if (errorMessage != null) {
      return AppErrorState(
        message: errorMessage,
        onRetry: () => unawaited(_controller.loadServicesByMotelId()),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.screen),
      children: [
        _buildHeader(context),
        const SizedBox(height: AppSpacing.s5),
        _buildStatistics(context),
        const SizedBox(height: AppSpacing.s5),
        LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 480;
            final search = AppSearchField(
              label: 'Buscar servicio',
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              onClear: _clearSearch,
            );
            final createButton = AppButton(
              label: 'Nuevo',
              icon: Icons.add,
              expanded: compact,
              onPressed: _openCreateForm,
            );
            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  search,
                  const SizedBox(height: AppSpacing.s3),
                  createButton,
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: search),
                const SizedBox(width: AppSpacing.s3),
                createButton,
              ],
            );
          },
        ),
        const SizedBox(height: AppSpacing.s6),
        Row(
          children: [
            Expanded(
              child: Text(
                'Servicios',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            Text(
              '${_filteredServices.length} registros',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: context.appColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s3),
        if (_filteredServices.isEmpty)
          const AppEmptyState(
            icon: Icons.miscellaneous_services_outlined,
            title: 'No hay servicios',
            message: 'No encontramos servicios que coincidan con la búsqueda.',
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _filteredServices.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.s3),
            itemBuilder: (context, index) {
              final service = _filteredServices[index];
              return _AdminServiceCard(
                service: service,
                onToggleActive: () => _controller.toggleActive(service),
                onEdit: () => _openEditForm(service),
                onDelete: () => _confirmDelete(service),
              );
            },
          ),
      ],
    );
  }

  void _openCreateForm() {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => AdditionalServiceAdminFormPage(controller: _controller),
      ),
    );
  }

  void _openEditForm(AdditionalService service) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => AdditionalServiceAdminFormPage(
          service: service,
          controller: _controller,
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Administración',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: AppSpacing.s1),
        Text(
          'Servicios adicionales',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: AppSpacing.s2),
        Text(
          'Crea y administra los servicios que estarán disponibles para los clientes.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: context.appColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildStatistics(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 600;
        final cards = [
          _StatisticCard(
            icon: Icons.miscellaneous_services_outlined,
            title: 'Total',
            value: '${_controller.services.length}',
          ),
          _StatisticCard(
            icon: Icons.check_circle_outline,
            title: 'Activos',
            value: '${_controller.activeCount}',
          ),
          _StatisticCard(
            icon: Icons.pause_circle_outline,
            title: 'Inactivos',
            value: '${_controller.inactiveCount}',
          ),
        ];
        if (compact) {
          return Column(
            children: [
              for (final card in cards) ...[
                card,
                const SizedBox(height: AppSpacing.s2),
              ],
            ],
          );
        }
        return Row(
          children: [
            for (var i = 0; i < cards.length; i++) ...[
              Expanded(child: cards[i]),
              if (i != cards.length - 1) const SizedBox(width: AppSpacing.s3),
            ],
          ],
        );
      },
    );
  }
}

class _StatisticCard extends StatelessWidget {
  const _StatisticCard({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          Container(
            width: AppSpacing.s12,
            height: AppSpacing.s12,
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(icon, color: Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(width: AppSpacing.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.appColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.s1),
                Text(value, style: Theme.of(context).textTheme.headlineSmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminServiceCard extends StatelessWidget {
  const _AdminServiceCard({
    required this.service,
    required this.onToggleActive,
    required this.onEdit,
    required this.onDelete,
  });

  final AdditionalService service;
  final VoidCallback onToggleActive;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: _serviceIconExtent,
                height: _serviceIconExtent,
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(
                  _iconFor(service.icon),
                  color: Theme.of(context).colorScheme.primary,
                  size: _serviceIconSize,
                ),
              ),
              const SizedBox(width: AppSpacing.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      service.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s1),
                    Text(
                      service.description,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.appColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Acciones',
                onSelected: (value) {
                  switch (value) {
                    case 'edit':
                      onEdit();
                      break;
                    case 'toggle':
                      onToggleActive();
                      break;
                    case 'delete':
                      onDelete();
                      break;
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: ListTile(
                      leading: Icon(Icons.edit_outlined),
                      title: Text('Editar'),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'toggle',
                    child: ListTile(
                      leading: Icon(Icons.power_settings_new_outlined),
                      title: Text(service.active ? 'Desactivar' : 'Activar'),
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      leading: Icon(Icons.delete_outline),
                      title: Text('Eliminar'),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s4),
          Row(
            children: [
              StatusBadge(
                status: service.active ? AppStatus.active : AppStatus.blocked,
              ),
              const Spacer(),
              Text(
                '\$${_formatPrice(service.price)}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _formatPrice(int value) {
  final text = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < text.length; i++) {
    if (i > 0 && (text.length - i) % 3 == 0) {
      buffer.write('.');
    }
    buffer.write(text[i]);
  }
  return buffer.toString();
}

IconData _iconFor(AdditionalServiceIcon icon) => switch (icon) {
  AdditionalServiceIcon.shield => Icons.shield_outlined,
  AdditionalServiceIcon.cloud => Icons.cloud_outlined,
  AdditionalServiceIcon.support => Icons.support_agent_outlined,
  AdditionalServiceIcon.cleaning => Icons.cleaning_services_outlined,
  AdditionalServiceIcon.miscellaneous => Icons.miscellaneous_services_outlined,
};
