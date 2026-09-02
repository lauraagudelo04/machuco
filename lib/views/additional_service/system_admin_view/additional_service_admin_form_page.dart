import 'package:flutter/material.dart';
import 'package:machuco/controllers/additional_service/additional_service_controller.dart';
import 'package:machuco/core/design_system/design_system.dart';
import 'package:machuco/models/additional_service/additional_service.dart';

class AdditionalServiceAdminFormPage extends StatefulWidget {
  const AdditionalServiceAdminFormPage({
    super.key,
    this.service,
    this.controller,
  });

  final AdditionalService? service;
  final AdditionalServiceController? controller;

  @override
  State<AdditionalServiceAdminFormPage> createState() =>
      _AdditionalServiceAdminFormPageState();
}

class _AdditionalServiceAdminFormPageState
    extends State<AdditionalServiceAdminFormPage> {
  late final AdditionalServiceController _controller;
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _categoryController;
  late final TextEditingController _priceController;
  bool get _isEditing => widget.service != null;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? AdditionalServiceController.instance;
    _controller
      ..resetFormValidation()
      ..addListener(_refresh);
    final service = widget.service;
    _nameController = TextEditingController(text: service?.name ?? '');
    _descriptionController = TextEditingController(
      text: service?.description ?? '',
    );
    _categoryController = TextEditingController(text: service?.category ?? '');
    _priceController = TextEditingController(
      text: service == null ? '' : '${service.price}',
    );
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _save() {
    final saved = _controller.save(
      service: widget.service,
      name: _nameController.text,
      description: _descriptionController.text,
      category: _categoryController.text,
      priceText: _priceController.text,
    );
    if (!saved) return;
    Navigator.of(context).pop(true);
  }

  @override
  void dispose() {
    _controller.removeListener(_refresh);
    _nameController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar servicio' : 'Nuevo servicio'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screen,
            AppSpacing.s5,
            AppSpacing.screen,
            AppSpacing.s8,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _isEditing
                        ? 'Actualiza la información del servicio disponible.'
                        : 'Crea un servicio para ofrecerlo a los clientes.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: context.appColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s5),
                  AppTextField(
                    label: 'Nombre',
                    hint: 'Ej. Decoración romántica',
                    controller: _nameController,
                    errorText: _controller.nameError,
                    prefixIcon: const Icon(Icons.title_outlined),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: AppSpacing.s4),
                  AppTextField(
                    label: 'Descripción',
                    hint: 'Describe qué incluye el servicio',
                    controller: _descriptionController,
                    errorText: _controller.descriptionError,
                    prefixIcon: const Icon(Icons.description_outlined),
                    maxLines: 3,
                  ),
                  const SizedBox(height: AppSpacing.s4),
                  AppTextField(
                    label: 'Categoría',
                    hint: 'Ej. Experiencias',
                    controller: _categoryController,
                    errorText: _controller.categoryError,
                    prefixIcon: const Icon(Icons.category_outlined),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: AppSpacing.s4),
                  AppTextField(
                    label: 'Precio',
                    hint: 'Ej. 25000',
                    controller: _priceController,
                    errorText: _controller.priceError,
                    prefixIcon: const Icon(Icons.attach_money_outlined),
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _save(),
                  ),
                  const SizedBox(height: AppSpacing.s6),
                  AppButton(
                    label: _isEditing ? 'Guardar cambios' : 'Crear servicio',
                    icon: _isEditing ? Icons.save_outlined : Icons.add,
                    onPressed: _save,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
