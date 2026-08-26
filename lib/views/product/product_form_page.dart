import 'package:flutter/material.dart';

import '../../core/design_system/design_system.dart';

class ProductViewData {
  const ProductViewData({
    required this.name,
    required this.description,
    required this.price,
    required this.stock,
    required this.isAvailable,
  });

  final String name;
  final String description;
  final double price;
  final int stock;
  final bool isAvailable;
}

class ProductFormView extends StatefulWidget {
  const ProductFormView({super.key, this.product});

  final ProductViewData? product;

  bool get isEditing => product != null;

  @override
  State<ProductFormView> createState() => _ProductFormViewState();
}

class _ProductFormViewState extends State<ProductFormView> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _priceController;
  late final TextEditingController _stockController;

  String? _nameError;
  String? _priceError;
  String? _stockError;
  late bool _isAvailable;

  @override
  void initState() {
    super.initState();
    final product = widget.product;
    _nameController = TextEditingController(text: product?.name ?? '');
    _descriptionController = TextEditingController(
      text: product?.description ?? '',
    );
    _priceController = TextEditingController(
      text: product == null ? '' : product.price.toStringAsFixed(0),
    );
    _stockController = TextEditingController(
      text: product == null ? '' : product.stock.toString(),
    );
    _isAvailable = product?.isAvailable ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    super.dispose();
  }

  void _saveProduct() {
    final name = _nameController.text.trim();
    final price = double.tryParse(_priceController.text.trim());
    final stock = int.tryParse(_stockController.text.trim());

    setState(() {
      _nameError = name.isEmpty ? 'El nombre es obligatorio' : null;
      _priceError = price == null || price < 0
          ? 'Ingresa un precio válido'
          : null;
      _stockError = stock == null || stock < 0
          ? 'Ingresa un stock válido'
          : null;
    });

    if (_nameError != null || _priceError != null || _stockError != null) {
      return;
    }

    Navigator.of(context).pop(
      ProductViewData(
        name: name,
        description: _descriptionController.text.trim(),
        price: price!,
        stock: stock!,
        isAvailable: _isAvailable,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Editar producto' : 'Nuevo producto'),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontalPadding = constraints.maxWidth < 360
                ? AppSpacing.screenCompact
                : AppSpacing.screen;

            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                AppSpacing.s5,
                horizontalPadding,
                AppSpacing.s8,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        widget.isEditing
                            ? 'Actualiza la información del producto.'
                            : 'Agrega un producto al catálogo del motel.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: context.appColors.textSecondary,
                            ),
                      ),
                      const SizedBox(height: AppSpacing.s5),
                      AppTextField(
                        label: 'Nombre',
                        hint: 'Ej. Gaseosa',
                        controller: _nameController,
                        errorText: _nameError,
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: AppSpacing.s4),
                      AppTextField(
                        label: 'Descripción',
                        hint: 'Descripción opcional',
                        controller: _descriptionController,
                        maxLines: 3,
                        textInputAction: TextInputAction.newline,
                      ),
                      const SizedBox(height: AppSpacing.s4),
                      AppTextField(
                        label: 'Precio',
                        hint: 'Ej. 8000',
                        controller: _priceController,
                        errorText: _priceError,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        textInputAction: TextInputAction.next,
                        prefixIcon: const Icon(Icons.attach_money),
                      ),
                      const SizedBox(height: AppSpacing.s4),
                      AppTextField(
                        label: 'Stock',
                        hint: 'Ej. 10',
                        controller: _stockController,
                        errorText: _stockError,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.done,
                        prefixIcon: const Icon(Icons.inventory_2_outlined),
                        onSubmitted: (_) => _saveProduct(),
                      ),
                      const SizedBox(height: AppSpacing.s4),
                      AppCard(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.s4,
                          vertical: AppSpacing.s2,
                        ),
                        child: SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Disponible'),
                          subtitle: const Text(
                            'Permite mostrar el producto como disponible.',
                          ),
                          value: _isAvailable,
                          onChanged: (value) {
                            setState(() => _isAvailable = value);
                          },
                        ),
                      ),
                      const SizedBox(height: AppSpacing.s6),
                      AppButton(
                        label: widget.isEditing
                            ? 'Guardar cambios'
                            : 'Crear producto',
                        icon: widget.isEditing ? Icons.save_outlined : Icons.add,
                        onPressed: _saveProduct,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
