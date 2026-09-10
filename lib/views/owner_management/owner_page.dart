import 'package:flutter/material.dart';

import 'package:machuco/core/design_system/components/app_card.dart';
import 'package:machuco/core/design_system/components/app_feedback.dart';
import 'package:machuco/core/design_system/components/app_icon_button.dart';
import 'package:machuco/core/design_system/components/app_text_field.dart';
import 'package:machuco/core/design_system/theme/app_theme_extensions.dart';
import 'package:machuco/core/design_system/tokens/app_spacing.dart';

import 'package:machuco/controllers/owner_management/owner_controller.dart';
import 'package:machuco/controllers/owner_management/platform_finance_summary.dart';
import 'package:machuco/models/owner_management/owner.dart';
import 'package:machuco/models/owner_management/owner_status_filter.dart';

import 'package:machuco/routes/routes.dart';
import 'package:machuco/views/motel/system_admin_view/admin_motels_page.dart';
import 'package:machuco/views/payment/payment_view_support.dart';

import 'owner_detail_page.dart';
import 'owner_form_page.dart';
import 'owner_summary.dart';

const _compactWidthBreakpoint = 360.0;
const _listMaxWidth = 640.0;

/// Lista de propietarios de moteles: es el punto de entrada del módulo.
///
/// Presenta el estado que expone `OwnerController` y le delega cada acción;
/// esta pantalla solo confirma el resultado al usuario.
class OwnerPage extends StatefulWidget {
  const OwnerPage({super.key});

  @override
  State<OwnerPage> createState() => _OwnerPageState();
}

class _OwnerPageState extends State<OwnerPage> {
  final OwnerController _controller = OwnerController();
  final PlatformFinanceSummary _financeSummary = PlatformFinanceSummary();
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _clearSearch() {
    _searchController.clear();
    _controller.search('');
  }

  void _clearFilters() {
    _searchController.clear();
    _controller.clearFilters();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _createOwner() async {
    final created = await Navigator.of(context).push<Owner>(
      MaterialPageRoute(builder: (_) => OwnerFormPage(controller: _controller)),
    );
    if (created == null || !mounted) return;
    _showMessage('${created.fullName} quedó registrado.');
  }

  Future<void> _editOwner(Owner owner) async {
    final updated = await Navigator.of(context).push<Owner>(
      MaterialPageRoute(
        builder: (_) =>
            OwnerFormPage(controller: _controller, initialData: owner),
      ),
    );
    if (updated == null || !mounted) return;
    _showMessage('Cambios guardados correctamente.');
  }

  Future<void> _openDetail(Owner owner) async {
    final wantsToEdit = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => OwnerDetailPage(owner: owner)),
    );
    if (wantsToEdit != true || !mounted) return;
    await _editOwner(owner);
  }

  void _openPlatformFinances() {
    Navigator.of(context).pushNamed(AppRoutes.adminPayments);
  }

  void _viewOwnerMotels(Owner owner) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AdminMotelsPage(
          initialOwnerId: owner.id,
          initialOwnerName: owner.fullName,
        ),
      ),
    );
  }

  Future<void> _toggleActiveState(Owner owner) async {
    // Inactivar deja al propietario sin operación, así que se confirma; volver
    // a activarlo es inocuo y no necesita confirmación.
    if (owner.isActive && !await _confirmDeactivation(owner)) return;
    if (!mounted) return;
    final updated = _controller.setActiveState(
      owner.id,
      isActive: !owner.isActive,
    );
    if (updated == null) return;
    _showMessage(
      updated.isActive
          ? '${updated.fullName} quedó activo.'
          : '${updated.fullName} quedó inactivo.',
    );
  }

  Future<void> _deleteOwner(Owner owner) async {
    if (!await _confirmDeletion(owner)) return;
    if (!mounted) return;
    final deleted = _controller.deleteOwner(owner.id);
    if (deleted == null) return;
    _showMessage('${deleted.fullName} fue eliminado.');
  }

  Future<bool> _confirmDeletion(Owner owner) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar propietario'),
        content: Text(
          '${owner.fullName} se eliminará de forma permanente y no podrás '
          'recuperarlo. Si solo quieres suspender su operación, usa Inactivar.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  Future<bool> _confirmDeactivation(Owner owner) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Inactivar propietario'),
        content: Text(
          '${owner.fullName} dejará de administrar sus moteles y de recibir '
          'reservas. Puedes volver a activarlo cuando quieras.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Inactivar'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Propietarios')),
      body: SafeArea(
        bottom: false,
        child: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) {
            if (!_controller.hasOwners) {
              return AppEmptyState(
                icon: Icons.people_outline,
                title: 'Aún no hay propietarios',
                message:
                    'Registra al primer propietario para asociarle sus moteles.',
                actionLabel: 'Crear propietario',
                onAction: _createOwner,
              );
            }
            return LayoutBuilder(
              builder: (context, constraints) {
                final horizontalPadding =
                    constraints.maxWidth < _compactWidthBreakpoint
                    ? AppSpacing.screenCompact
                    : AppSpacing.screen;
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: _listMaxWidth),
                    child: CustomScrollView(
                      slivers: [
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(
                              horizontalPadding,
                              AppSpacing.s4,
                              horizontalPadding,
                              AppSpacing.s2,
                            ),
                            child: _PlatformFinanceBanner(
                              totals: _financeSummary.totals,
                              onTap: _openPlatformFinances,
                            ),
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: _OwnerFilterBar(
                            searchController: _searchController,
                            selectedFilter: _controller.statusFilter,
                            onSearchChanged: _controller.search,
                            onClearSearch: _clearSearch,
                            onFilterSelected: _controller.filterByStatus,
                          ),
                        ),
                        if (_controller.hasVisibleOwners)
                          _OwnerList(
                            owners: _controller.visibleOwners,
                            horizontalPadding: horizontalPadding,
                            onDetail: _openDetail,
                            onEdit: _editOwner,
                            onToggleActive: _toggleActiveState,
                            onDelete: _deleteOwner,
                            onViewMotels: _viewOwnerMotels,
                          )
                        else
                          SliverFillRemaining(
                            hasScrollBody: false,
                            child: AppEmptyState(
                              icon: Icons.search_off,
                              title: 'Sin resultados',
                              message:
                                  'Ningún propietario coincide con tu búsqueda o filtro.',
                              actionLabel: 'Limpiar filtros',
                              onAction: _clearFilters,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createOwner,
        tooltip: 'Crear propietario',
        child: const Icon(Icons.add),
      ),
    );
  }
}

/// Barra con la búsqueda y el filtro por estado del listado.
///
/// Se desplaza junto con el resto de la página: el resumen de finanzas, los
/// filtros y las tarjetas forman un solo recorrido vertical.
class _OwnerFilterBar extends StatelessWidget {
  const _OwnerFilterBar({
    required this.searchController,
    required this.selectedFilter,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.onFilterSelected,
  });

  final TextEditingController searchController;
  final OwnerStatusFilter selectedFilter;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final ValueChanged<OwnerStatusFilter> onFilterSelected;

  @override
  Widget build(BuildContext context) {
    final hasQuery = searchController.text.isNotEmpty;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.appColors.canvas,
        border: Border(bottom: BorderSide(color: context.appColors.border)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final horizontalPadding =
              constraints.maxWidth < _compactWidthBreakpoint
              ? AppSpacing.screenCompact
              : AppSpacing.screen;
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _listMaxWidth),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  AppSpacing.s4,
                  horizontalPadding,
                  AppSpacing.s3,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppSearchField(
                      label: 'Buscar por nombre, documento o correo',
                      controller: searchController,
                      onChanged: onSearchChanged,
                      onClear: hasQuery ? onClearSearch : null,
                    ),
                    const SizedBox(height: AppSpacing.s3),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final filter in OwnerStatusFilter.values)
                            Padding(
                              padding: const EdgeInsets.only(
                                right: AppSpacing.s2,
                              ),
                              child: ChoiceChip(
                                label: Text(filter.label),
                                selected: filter == selectedFilter,
                                onSelected: (_) => onFilterSelected(filter),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Listado desplazable de propietarios, centrado y con ancho acotado.
class _OwnerList extends StatelessWidget {
  const _OwnerList({
    required this.owners,
    required this.horizontalPadding,
    required this.onDetail,
    required this.onEdit,
    required this.onToggleActive,
    required this.onDelete,
    required this.onViewMotels,
  });

  final List<Owner> owners;
  final double horizontalPadding;
  final ValueChanged<Owner> onDetail;
  final ValueChanged<Owner> onEdit;
  final ValueChanged<Owner> onToggleActive;
  final ValueChanged<Owner> onDelete;
  final ValueChanged<Owner> onViewMotels;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        AppSpacing.s5,
        horizontalPadding,
        // Deja respirar la última tarjeta por encima del FAB.
        AppSpacing.s12 + AppSpacing.s5,
      ),
      sliver: SliverList.separated(
        itemCount: owners.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.s3),
        itemBuilder: (context, index) {
          final owner = owners[index];
          return _OwnerCard(
            owner: owner,
            onDetail: () => onDetail(owner),
            onEdit: () => onEdit(owner),
            onToggleActive: () => onToggleActive(owner),
            onDelete: () => onDelete(owner),
            onViewMotels: () => onViewMotels(owner),
          );
        },
      ),
    );
  }
}

/// Bloque compacto con los totales de la plataforma.
///
/// Muestra solo las dos cifras principales; el detalle completo vive en la
/// pantalla de finanzas globales, a la que se llega tocando la tarjeta.
class _PlatformFinanceBanner extends StatelessWidget {
  const _PlatformFinanceBanner({required this.totals, required this.onTap});

  final PlatformFinanceTotals totals;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return AppCard(
      onTap: onTap,
      semanticLabel: 'Ver las finanzas globales de la plataforma',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.insights_outlined, color: colors.textSecondary),
              const SizedBox(width: AppSpacing.s2),
              Expanded(
                child: Text(
                  'Finanzas de la plataforma',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Icon(Icons.chevron_right, color: colors.textSecondary),
            ],
          ),
          const SizedBox(height: AppSpacing.s3),
          Row(
            children: [
              Expanded(
                child: _FinanceMetric(
                  label: 'Ingresos',
                  value: formatPaymentMoney(totals.income),
                ),
              ),
              const SizedBox(width: AppSpacing.s3),
              Expanded(
                child: _FinanceMetric(
                  label: 'Por recaudar',
                  value: formatPaymentMoney(totals.pendingAmount),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Etiqueta y cifra de una métrica dentro del bloque de finanzas.
class _FinanceMetric extends StatelessWidget {
  const _FinanceMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: textTheme.bodySmall?.copyWith(
            color: context.appColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.s1),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value, style: textTheme.titleLarge),
        ),
      ],
    );
  }
}

/// Tarjeta de un propietario con sus acciones disponibles.
class _OwnerCard extends StatelessWidget {
  const _OwnerCard({
    required this.owner,
    required this.onDetail,
    required this.onEdit,
    required this.onToggleActive,
    required this.onDelete,
    required this.onViewMotels,
  });

  final Owner owner;
  final VoidCallback onDetail;
  final VoidCallback onEdit;
  final VoidCallback onToggleActive;
  final VoidCallback onDelete;
  final VoidCallback onViewMotels;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return AppCard(
      onTap: onDetail,
      semanticLabel: '${owner.fullName}, ${owner.documentLabel}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(owner.fullName, style: textTheme.titleMedium),
              ),
              const SizedBox(width: AppSpacing.s2),
              OwnerStatusChip(isActive: owner.isActive),
            ],
          ),
          const SizedBox(height: AppSpacing.s2),
          _OwnerDetailLine(
            icon: Icons.badge_outlined,
            text: owner.documentLabel,
          ),
          _OwnerDetailLine(icon: Icons.mail_outline, text: owner.email),
          _OwnerDetailLine(icon: Icons.phone_outlined, text: owner.phone),
          const SizedBox(height: AppSpacing.s2),
          // Wrap y no Row: en pantallas angostas las cinco acciones no caben
          // en una linea y deben bajar a la siguiente en vez de desbordarse.
          Wrap(
            alignment: WrapAlignment.end,
            spacing: AppSpacing.s2,
            runSpacing: AppSpacing.s2,
            children: [
              AppIconButton(
                icon: Icons.domain_outlined,
                tooltip: 'Ver moteles de ${owner.fullName}',
                onPressed: onViewMotels,
              ),
              AppIconButton(
                icon: Icons.visibility_outlined,
                tooltip: 'Ver detalle de ${owner.fullName}',
                onPressed: onDetail,
              ),
              AppIconButton(
                icon: Icons.edit_outlined,
                tooltip: 'Editar a ${owner.fullName}',
                onPressed: onEdit,
              ),
              AppIconButton(
                icon: owner.isActive
                    ? Icons.block_outlined
                    : Icons.check_circle_outline,
                tooltip: owner.isActive
                    ? 'Inactivar a ${owner.fullName}'
                    : 'Activar a ${owner.fullName}',
                variant: owner.isActive
                    ? AppIconButtonVariant.destructive
                    : AppIconButtonVariant.standard,
                onPressed: onToggleActive,
              ),
              AppIconButton(
                icon: Icons.delete_outline,
                tooltip: 'Eliminar a ${owner.fullName}',
                variant: AppIconButtonVariant.destructive,
                onPressed: onDelete,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OwnerDetailLine extends StatelessWidget {
  const _OwnerDetailLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final color = context.appColors.textSecondary;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.s1),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: AppSpacing.s2),
          Expanded(
            child: Text(
              text,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: color),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
