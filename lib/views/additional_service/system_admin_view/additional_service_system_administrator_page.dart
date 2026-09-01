import 'package:flutter/material.dart';
import 'package:machuco/controllers/additional_service/additional_service_controller.dart';
import 'package:machuco/models/additional_service/additional_service.dart';
import 'package:machuco/routes/routes.dart';
import '../../../../core/design_system/components/app_button.dart';
import '../../../../core/design_system/components/app_card.dart';
import '../../../../core/design_system/components/app_text_field.dart';
import '../../../../core/design_system/components/status_badge.dart';
import '../../../../core/design_system/theme/app_theme_extensions.dart';
import '../../../../core/design_system/tokens/app_radius.dart';
import '../../../../core/design_system/tokens/app_spacing.dart';

class AdditionalServiceSystemAdministratorPage extends StatefulWidget {
  const AdditionalServiceSystemAdministratorPage({super.key, this.controller});

  final AdditionalServiceController? controller;

  @override
  State<AdditionalServiceSystemAdministratorPage> createState() =>
      _AdditionalServiceSystemAdministratorPageState();
}

class _AdditionalServiceSystemAdministratorPageState
    extends State<AdditionalServiceSystemAdministratorPage> {
  final TextEditingController _searchController = TextEditingController();

  late final AdditionalServiceController _controller;

  List<AdditionalService> get _filteredServices =>
      _controller.searchAdmin(_searchController.text);

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? AdditionalServiceController.instance;
    _controller.addListener(_refresh);
  }

  void _refresh() => setState(() {});

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
    _controller.removeListener(_refresh);
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Servicios adicionales')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.screen),
          children: [
            _buildHeader(context),
            const SizedBox(height: AppSpacing.s5),
            _buildStatistics(context),
            const SizedBox(height: AppSpacing.s5),
            Row(
              children: [
                Expanded(
                  child: AppTextField(
                    label: 'Buscar servicio',
                    controller: _searchController,
                    hint: 'Nombre, categoría...',
                    prefixIcon: const Icon(Icons.search),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: AppSpacing.s3),
                AppButton(
                  label: 'Nuevo',
                  icon: Icons.add,
                  expanded: false,
                  onPressed: () => Navigator.pushNamed(
                    context,
                    AppRoutes.createAdminAdditionalService,
                  ),
                ),
              ],
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
              _buildEmptyState(context)
            else
              ..._filteredServices.map(
                (service) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.s3),
                  child: _AdminServiceCard(
                    service: service,
                    onToggleActive: () => _controller.toggleActive(service),
                    onEdit: () => Navigator.pushNamed(
                      context,
                      AppRoutes.createAdminAdditionalService,
                      arguments: service,
                    ),
                    onDelete: () => _confirmDelete(service),
                  ),
                ),
              ),
          ],
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

  Widget _buildEmptyState(BuildContext context) {
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s6),
        child: Column(
          children: [
            Icon(
              Icons.miscellaneous_services_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: AppSpacing.s3),
            Text(
              'No hay servicios',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.s2),
            Text(
              'No encontramos servicios que coincidan con la búsqueda.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: context.appColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
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
            width: 44,
            height: 44,
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
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(
                  _iconFor(service.icon),
                  color: Theme.of(context).colorScheme.primary,
                  size: 26,
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
