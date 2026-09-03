import 'dart:async';

import 'package:flutter/material.dart';
import 'package:machuco/controllers/additional_service/client_view/additional_service_client_controller.dart';
import 'package:machuco/core/design_system/design_system.dart';
import 'package:machuco/models/additional_service/additional_service.dart';
import 'package:machuco/views/additional_service/client_view/add_additional_service_client_page.dart';

const _serviceIconExtent = 52.0;
const _serviceIconSize = 26.0;

class AdditionalServiceClientPage extends StatefulWidget {
  const AdditionalServiceClientPage({super.key, this.controller});

  final AdditionalServiceClientController? controller;

  @override
  State<AdditionalServiceClientPage> createState() =>
      _AdditionalServiceClientPageState();
}

class _AdditionalServiceClientPageState
    extends State<AdditionalServiceClientPage> {
  final TextEditingController _searchController = TextEditingController();

  late final AdditionalServiceClientController _controller;
  bool _controllerInitialized = false;

  List<AdditionalService> get _filteredServices =>
      _controller.searchSelected(_searchController.text);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controllerInitialized) return;
    final routeArgument = ModalRoute.of(context)?.settings.arguments;
    _controller =
        widget.controller ??
        AdditionalServiceClientController(
          userId: routeArgument is String
              ? routeArgument
              : AdditionalServiceClientController.demoUserId,
        );
    _controllerInitialized = true;
    _controller.addListener(_refresh);
    unawaited(_controller.loadServicesByUserId());
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

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
    if (_controllerInitialized) _controller.removeListener(_refresh);
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
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) =>
                    AddAdditionalServiceClientPage(controller: _controller),
              ),
            ),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
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
          AppSkeleton(height: 56),
          SizedBox(height: AppSpacing.s6),
          AppSkeleton(height: 148),
          SizedBox(height: AppSpacing.s3),
          AppSkeleton(height: 148),
        ],
      );
    }

    final errorMessage = _controller.errorMessage;
    if (errorMessage != null) {
      return AppErrorState(
        message: errorMessage,
        onRetry: () => unawaited(_controller.loadServicesByUserId()),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.screen),
      children: [
        _buildHeader(context),
        const SizedBox(height: AppSpacing.s5),
        AppSearchField(
          label: 'Buscar servicios',
          controller: _searchController,
          onChanged: (_) => setState(() {}),
          onClear: _clearSearch,
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
            title: 'No encontramos servicios',
            message: 'Prueba con otro término de búsqueda.',
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _filteredServices.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.s3),
            itemBuilder: (context, index) {
              final service = _filteredServices[index];
              return _ClientServiceCard(
                service: service,
                selected: _controller.isSelected(service),
                onPressed: () => _confirmRemove(service),
              );
            },
          ),
        if (_controller.selectedCount > 0) _buildSelectedSummary(context),
      ],
    );
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {});
  }

  void _openSelection() {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => AddAdditionalServiceClientPage(controller: _controller),
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

  Widget _buildSelectedSummary(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.s3),
      child: AppCard(
        selected: true,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 480;
            final information = Row(
              children: [
                Container(
                  width: AppSpacing.s12,
                  height: AppSpacing.s12,
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
                Expanded(child: _buildSummaryText(context)),
              ],
            );
            final button = AppButton(
              label: 'Administrar',
              expanded: compact,
              size: AppButtonSize.medium,
              onPressed: _openSelection,
            );
            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  information,
                  const SizedBox(height: AppSpacing.s3),
                  button,
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: information),
                const SizedBox(width: AppSpacing.s3),
                button,
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSummaryText(BuildContext context) {
    return Column(
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
