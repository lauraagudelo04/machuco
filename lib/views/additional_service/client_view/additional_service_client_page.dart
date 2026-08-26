import 'package:flutter/material.dart';
import '../../../../core/design_system/components/app_button.dart';
import '../../../../core/design_system/components/app_card.dart';
import '../../../../core/design_system/components/app_icon_button.dart';
import '../../../../core/design_system/components/app_text_field.dart';
import '../../../../core/design_system/tokens/app_radius.dart';
import '../../../../core/design_system/tokens/app_spacing.dart';
import '../../../../core/design_system/theme/app_theme_extensions.dart';

class AdditionalServiceClientPage extends StatefulWidget {
  const AdditionalServiceClientPage({super.key});

  @override
  State<AdditionalServiceClientPage> createState() =>
      _AdditionalServiceClientPageState();
}

class _AdditionalServiceClientPageState
    extends State<AdditionalServiceClientPage> {
  final TextEditingController _searchController = TextEditingController();

  final List<_ClientService> _services = const [
    _ClientService(
      icon: Icons.shield_outlined,
      name: 'Seguro de pantalla',
      description: 'Protección para tu dispositivo ante daños accidentales.',
      category: 'Protección',
      price: 9900,
    ),
    _ClientService(
      icon: Icons.cloud_outlined,
      name: 'Respaldo en la nube',
      description: 'Mantén tus archivos y fotografías respaldados de forma segura.',
      category: 'Almacenamiento',
      price: 5900,
    ),
    _ClientService(
      icon: Icons.support_agent_outlined,
      name: 'Asistencia técnica',
      description: 'Obtén asistencia y soporte cuando lo necesites.',
      category: 'Soporte',
      price: 12900,
    ),
    _ClientService(
      icon: Icons.cleaning_services_outlined,
      name: 'Limpieza adicional',
      description: 'Servicio de limpieza adicional durante tu estadía.',
      category: 'Servicios',
      price: 7900,
    ),
  ];

  final Set<String> _selectedServices = {};
  String _selectedCategory = 'Todos';

  List<String> get _categories {
    final categories = <String>{'Todos', ..._services.map((e) => e.category)};
    return categories.toList();
  }

  List<_ClientService> get _filteredServices {
    final query = _searchController.text.trim().toLowerCase();
    return _services.where((service) {
      final matchCategory = _selectedCategory == 'Todos' ||
          service.category == _selectedCategory;
      final matchSearch = query.isEmpty ||
          service.name.toLowerCase().contains(query) ||
          service.description.toLowerCase().contains(query);
      return matchCategory && matchSearch;
    }).toList();
  }

  void _toggleService(_ClientService service) {
    setState(() {
      if (_selectedServices.contains(service.name)) {
        _selectedServices.remove(service.name);
      } else {
        _selectedServices.add(service.name);
      }
    });
  }

  int get _selectedCount => _selectedServices.length;
  int get _selectedTotal => _services
      .where((s) => _selectedServices.contains(s.name))
      .fold(0, (sum, s) => sum + s.price);

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
                  const SizedBox(height: AppSpacing.s4),
                  _buildCategories(context),
                  const SizedBox(height: AppSpacing.s6),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Servicios disponibles',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ),
                      Text(
                        '${_filteredServices.length} disponibles',
                        style: Theme.of(context)
                            .textTheme
                            .labelMedium
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
                        child: _ClientServiceCard(
                          service: service,
                          selected: _selectedServices.contains(service.name),
                          onPressed: () => _toggleService(service),
                        ),
                      ),
                    ),
                  if (_selectedCount > 0)
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
          'Agrega servicios a tu reserva',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: AppSpacing.s2),
        Text(
          'Personaliza tu experiencia seleccionando los servicios adicionales que necesites.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: context.appColors.textSecondary,
              ),
        ),
      ],
    );
  }

  Widget _buildCategories(BuildContext context) {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        separatorBuilder: (context, index) =>
            const SizedBox(width: AppSpacing.s2),
        itemBuilder: (context, index) {
          final category = _categories[index];
          final selected = category == _selectedCategory;
          return ChoiceChip(
            label: Text(category),
            selected: selected,
            onSelected: (_) {
              setState(() => _selectedCategory = category);
            },
          );
        },
      ),
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
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: .12),
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
                    '$_selectedCount servicio(s) seleccionado(s)',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.s1),
                  Text(
                    'Total estimado: \$${_formatPrice(_selectedTotal)}',
                    style:
                        Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: context.appColors.textSecondary,
                            ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.s2),
            AppButton(
              label: 'Continuar',
              expanded: false,
              size: AppButtonSize.medium,
              onPressed: () {},
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

  final _ClientService service;
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
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              AppButton(
                label: selected ? 'Seleccionado' : 'Agregar',
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

class _ClientService {
  const _ClientService({
    required this.icon,
    required this.name,
    required this.description,
    required this.category,
    required this.price,
  });

  final IconData icon;
  final String name;
  final String description;
  final String category;
  final int price;
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
