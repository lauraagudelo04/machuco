import 'package:flutter/material.dart';
import '../../../../core/design_system/components/app_button.dart';
import '../../../../core/design_system/components/app_card.dart';
import '../../../../core/design_system/components/app_text_field.dart';
import '../../../../core/design_system/components/status_badge.dart';
import '../../../../core/design_system/theme/app_theme_extensions.dart';
import '../../../../core/design_system/tokens/app_radius.dart';
import '../../../../core/design_system/tokens/app_spacing.dart';

class AdditionalServiceSystemAdministratorPage
    extends StatefulWidget {
  const AdditionalServiceSystemAdministratorPage({super.key});

  @override
  State<AdditionalServiceSystemAdministratorPage> createState() =>
      _AdditionalServiceSystemAdministratorPageState();
}

class _AdditionalServiceSystemAdministratorPageState
    extends State<AdditionalServiceSystemAdministratorPage> {
  final TextEditingController _searchController = TextEditingController();

  final List<_AdminService> _services = [
    _AdminService(
      icon: Icons.shield_outlined,
      name: 'Seguro de pantalla',
      description: 'Protección para dispositivos ante daños accidentales.',
      category: 'Protección',
      price: 9900,
      active: true,
    ),
    _AdminService(
      icon: Icons.cloud_outlined,
      name: 'Respaldo en la nube',
      description: 'Almacenamiento seguro para archivos y fotografías.',
      category: 'Almacenamiento',
      price: 5900,
      active: true,
    ),
    _AdminService(
      icon: Icons.support_agent_outlined,
      name: 'Asistencia técnica',
      description: 'Servicio de asistencia y soporte técnico.',
      category: 'Soporte',
      price: 12900,
      active: true,
    ),
    _AdminService(
      icon: Icons.cleaning_services_outlined,
      name: 'Limpieza adicional',
      description: 'Servicio adicional de limpieza durante la estadía.',
      category: 'Servicios',
      price: 7900,
      active: false,
    ),
  ];

  List<_AdminService> get _filteredServices {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _services;
    return _services.where((service) {
      return service.name.toLowerCase().contains(query) ||
          service.description.toLowerCase().contains(query) ||
          service.category.toLowerCase().contains(query);
    }).toList();
  }

  int get _activeCount =>
      _services.where((service) => service.active).length;

  int get _inactiveCount =>
      _services.where((service) => !service.active).length;

  void _toggleActive(_AdminService service) {
    setState(() => service.active = !service.active);
  }

  void _deleteService(_AdminService service) {
    setState(() => _services.remove(service));
  }

  void _openForm([_AdminService? service]) {
    final isEdit = service != null;
    final nameController = TextEditingController(text: isEdit ? service.name : '');
    final descriptionController = TextEditingController(text: isEdit ? service.description : '');
    final categoryController = TextEditingController(text: isEdit ? service.category : '');
    final priceController = TextEditingController(text: isEdit ? '${service.price}' : '');
    final icon = isEdit ? service.icon : Icons.miscellaneous_services_outlined;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.s5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isEdit ? 'Editar servicio' : 'Nuevo servicio',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: AppSpacing.s4),
              AppTextField(
                label: 'Nombre',
                controller: nameController,
                hint: 'Nombre del servicio',
                prefixIcon: const Icon(Icons.title_outlined),
              ),
              const SizedBox(height: AppSpacing.s3),
              AppTextField(
                label: 'Descripción',
                controller: descriptionController,
                hint: 'Descripción breve',
                maxLines: 3,
                prefixIcon: const Icon(Icons.description_outlined),
              ),
              const SizedBox(height: AppSpacing.s3),
              AppTextField(
                label: 'Categoría',
                controller: categoryController,
                hint: 'Ej: Soporte',
                prefixIcon: const Icon(Icons.category_outlined),
              ),
              const SizedBox(height: AppSpacing.s3),
              AppTextField(
                label: 'Precio',
                controller: priceController,
                hint: '0',
                keyboardType: TextInputType.number,
                prefixIcon: const Icon(Icons.attach_money_outlined),
              ),
              const SizedBox(height: AppSpacing.s4),
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      label: 'Cancelar',
                      expanded: true,
                      variant: AppButtonVariant.secondary,
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s3),
                  Expanded(
                    child: AppButton(
                      label: isEdit ? 'Guardar' : 'Crear',
                      expanded: true,
                      onPressed: () {
                        final name = nameController.text.trim();
                        final description = descriptionController.text.trim();
                        final category = categoryController.text.trim();
                        final price = int.tryParse(priceController.text.trim()) ?? 0;
                        if (name.isEmpty || description.isEmpty || category.isEmpty || price <= 0) return;
                        setState(() {
                          if (isEdit) {
                            service.name = name;
                            service.description = description;
                            service.category = category;
                            service.price = price;
                          } else {
                            _services.add(_AdminService(
                              icon: icon,
                              name: name,
                              description: description,
                              category: category,
                              price: price,
                              active: true,
                            ));
                          }
                        });
                        Navigator.pop(context);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s6),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Servicios adicionales'),
      ),
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
                  onPressed: () => _openForm(),
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
                  style: Theme.of(context)
                      .textTheme.labelMedium
                      ?.copyWith(
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
                    onToggleActive: () => _toggleActive(service),
                    onEdit: () => _openForm(service),
                    onDelete: () => _deleteService(service),
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
            value: '${_services.length}',
          ),
          _StatisticCard(
            icon: Icons.check_circle_outline,
            title: 'Activos',
            value: '$_activeCount',
          ),
          _StatisticCard(
            icon: Icons.pause_circle_outline,
            title: 'Inactivos',
            value: '$_inactiveCount',
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
              if (i != cards.length - 1)
                const SizedBox(width: AppSpacing.s3),
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
              color: Theme.of(context)
                  .colorScheme
                  .primary
                  .withValues(alpha: .10),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(
              icon,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: AppSpacing.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(
                        color: context.appColors.textSecondary,
                      ),
                ),
                const SizedBox(height: AppSpacing.s1),
                Text(
                  value,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
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

  final _AdminService service;
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
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(
                  service.icon,
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
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: AppSpacing.s1),
                    Text(
                      service.description,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(
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
                      title: Text(
                        service.active
                            ? 'Desactivar'
                            : 'Activar',
                      ),
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
                status: service.active
                    ? AppStatus.active
                    : AppStatus.blocked,
              ),
              const Spacer(),
              Text(
                '\$${_formatPrice(service.price)}',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(
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

class _AdminService {
  _AdminService({
    required this.icon,
    required this.name,
    required this.description,
    required this.category,
    required this.price,
    required this.active,
  });

  IconData icon;
  String name;
  String description;
  String category;
  int price;
  bool active;
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
