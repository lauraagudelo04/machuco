import 'package:flutter/material.dart';
import 'package:machuco/controllers/additional_service/additional_service_controller.dart';
import 'package:machuco/core/design_system/design_system.dart';
import 'package:machuco/models/additional_service/additional_service.dart';

class AddAdditionalServiceClientPage extends StatefulWidget {
  const AddAdditionalServiceClientPage({super.key, this.controller});

  final AdditionalServiceController? controller;

  @override
  State<AddAdditionalServiceClientPage> createState() =>
      _AddAdditionalServiceClientPageState();
}

class _AddAdditionalServiceClientPageState
    extends State<AddAdditionalServiceClientPage> {
  final TextEditingController _searchController = TextEditingController();
  late final AdditionalServiceController _controller;
  String _category = 'Todos';

  List<AdditionalService> get _services =>
      _controller.searchClient(_searchController.text, _category);

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? AdditionalServiceController.instance;
    _controller
      ..beginSelection()
      ..addListener(_refresh);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _confirm() {
    _controller.confirmSelection();
    Navigator.of(context).pop(true);
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
      appBar: AppBar(title: const Text('Agregar servicios')),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(AppSpacing.screen),
        child: AppButton(
          label: 'Guardar ${_controller.draftSelectedCount} servicio(s)',
          icon: Icons.check,
          onPressed: _confirm,
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.screen),
          children: [
            Text(
              'Elige tus servicios',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: AppSpacing.s2),
            Text(
              'Selecciona o quita los servicios que deseas asociar a tu cuenta.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: context.appColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.s5),
            AppTextField(
              label: 'Buscar servicios',
              hint: 'Nombre o descripción',
              controller: _searchController,
              prefixIcon: const Icon(Icons.search),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: AppSpacing.s4),
            SizedBox(
              height: 42,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _controller.categories.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(width: AppSpacing.s2),
                itemBuilder: (context, index) {
                  final category = _controller.categories[index];
                  return ChoiceChip(
                    label: Text(category),
                    selected: category == _category,
                    onSelected: (_) => setState(() => _category = category),
                  );
                },
              ),
            ),
            const SizedBox(height: AppSpacing.s5),
            ..._services.map(
              (service) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.s3),
                child: AppCard(
                  selected: _controller.isDraftSelected(service),
                  onTap: () => _controller.toggleDraftSelected(service),
                  child: Row(
                    children: [
                      Icon(
                        _iconFor(service.icon),
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: AppSpacing.s3),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              service.name,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: AppSpacing.s1),
                            Text(
                              service.description,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: context.appColors.textSecondary,
                                  ),
                            ),
                            const SizedBox(height: AppSpacing.s2),
                            Text(
                              '\$${_formatPrice(service.price)}',
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      Checkbox(
                        value: _controller.isDraftSelected(service),
                        onChanged: (_) =>
                            _controller.toggleDraftSelected(service),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.s2),
            AppCard(
              selected: true,
              child: Row(
                children: [
                  const Icon(Icons.receipt_long_outlined),
                  const SizedBox(width: AppSpacing.s3),
                  const Expanded(child: Text('Total estimado')),
                  Text(
                    '\$${_formatPrice(_controller.draftSelectedTotal)}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatPrice(int value) {
  final text = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < text.length; i++) {
    if (i > 0 && (text.length - i) % 3 == 0) buffer.write('.');
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
