import 'package:flutter/material.dart';
import 'package:machuco/controllers/additional_service/additional_service_controller.dart';
import 'package:machuco/models/additional_service/additional_service.dart';
import 'package:machuco/routes/routes.dart';
import '../../../../core/design_system/components/app_button.dart';
import '../../../../core/design_system/components/app_card.dart';
import '../../../../core/design_system/components/app_icon_button.dart';
import '../../../../core/design_system/components/app_text_field.dart';
import '../../../../core/design_system/tokens/app_radius.dart';
import '../../../../core/design_system/tokens/app_spacing.dart';
import '../../../../core/design_system/theme/app_theme_extensions.dart';

class AdditionalServiceClientPage extends StatefulWidget {
  const AdditionalServiceClientPage({super.key, this.controller});

  final AdditionalServiceController? controller;

  @override
  State<AdditionalServiceClientPage> createState() =>
      _AdditionalServiceClientPageState();
}

class _AdditionalServiceClientPageState
    extends State<AdditionalServiceClientPage> {
  final TextEditingController _searchController = TextEditingController();

  late final AdditionalServiceController _controller;

  List<AdditionalService> get _filteredServices =>
      _controller.searchSelected(_searchController.text);

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? AdditionalServiceController.instance;
    _controller.addListener(_refresh);
  }

  void _refresh() => setState(() {});

  Future<void> _confirmRemove(AdditionalService service) async {
    final shouldRemove = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Quitar servicio'),
        content: Text(
          '¿Estás seguro de que deseas quitar “${service.name}” de tus servicios?',
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
            child: const Text('Sí, quitar'),
          ),
        ],
      ),
    );
    if (!mounted || shouldRemove != true) return;
    _controller.removeSelected(service);
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
      appBar: AppBar(
        title: const Text('Servicios adicionales'),
        actions: [
          IconButton(
            tooltip: 'Agregar servicios',
            onPressed: () => Navigator.pushNamed(
              context,
              AppRoutes.addClientAdditionalServices,
            ),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.screen),
                children: [
                  _buildHeader(context),
                  const SizedBox(height: AppSpacing.s5),
                  AppTextField(
                    label: 'Buscar servicios',
                    controller: _searchController,
                    hint: '¿Qué servicio necesitas?',
                    prefixIcon: const Icon(Icons.search),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: AppSpacing.s6),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Mis servicios asociados',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ),
                      Text(
                        '${_filteredServices.length} asociados',
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(color: context.appColors.textSecondary),
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
                        child: _ClientServiceCard(
                          service: service,
                          selected: _controller.isSelected(service),
                          onPressed: () => _confirmRemove(service),
                        ),
                      ),
                    ),
                  if (_controller.selectedCount > 0)
                    _buildSelectedSummary(context),
                ],
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
          'Tus servicios adicionales',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: AppSpacing.s2),
        Text(
          'Consulta y administra los servicios que tienes asociados.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: context.appColors.textSecondary,
          ),
        ),
      ],
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
              'No encontramos servicios',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.s2),
            Text(
              'Prueba con otro término de búsqueda o categoría.',
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

  Widget _buildSelectedSummary(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.s3),
      child: AppCard(
        selected: true,
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(
                Icons.check_circle_outline,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: AppSpacing.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_controller.selectedCount} servicio(s) seleccionado(s)',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.s1),
                  Text(
                    'Total estimado: \$${_formatPrice(_controller.selectedTotal)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: context.appColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.s2),
            AppButton(
              label: 'Administrar',
              expanded: false,
              size: AppButtonSize.medium,
              onPressed: () => Navigator.pushNamed(
                context,
                AppRoutes.addClientAdditionalServices,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClientServiceCard extends StatelessWidget {
  const _ClientServiceCard({
    required this.service,
    required this.selected,
    required this.onPressed,
  });

  final AdditionalService service;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      selected: selected,
      onTap: onPressed,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
              if (selected)
                AppIconButton(
                  icon: Icons.check,
                  tooltip: 'Servicio seleccionado',
                  onPressed: onPressed,
                  variant: AppIconButtonVariant.standard,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.s4),
          Row(
            children: [
              Expanded(
                child: Text(
                  '\$${_formatPrice(service.price)}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              AppButton(
                label: selected ? 'Quitar' : 'Agregar',
                expanded: false,
                size: AppButtonSize.medium,
                variant: selected
                    ? AppButtonVariant.secondary
                    : AppButtonVariant.primary,
                onPressed: onPressed,
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
