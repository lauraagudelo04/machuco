import 'package:flutter/material.dart';
import '../../../core/design_system/design_system.dart';

class OwnerMotelFormPage extends StatefulWidget {
  // Si es true, estamos editando un motel existente. Si es false, estamos creando uno nuevo.
  const OwnerMotelFormPage({super.key, this.isEditing = false});

  final bool isEditing;

  @override
  State<OwnerMotelFormPage> createState() => _OwnerMotelFormPageState();
}

class _OwnerMotelFormPageState extends State<OwnerMotelFormPage> {
  // Controladores básicos para el ejemplo
  final _emailController = TextEditingController();
  final _nameController = TextEditingController();
  final _roomsController = TextEditingController();
  final _nitController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();

  // Estado para los chips de métodos de pago
  final List<String> _selectedPaymentMethods = ['Efectivo'];
  final List<String> _availablePaymentMethods = [
    'Efectivo',
    'Tarjeta Crédito/Débito',
    'Transferencia',
    'Nequi / Daviplata',
  ];

  @override
  void dispose() {
    _emailController.dispose();
    _nameController.dispose();
    _roomsController.dispose();
    _nitController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _togglePaymentMethod(String method) {
    setState(() {
      if (_selectedPaymentMethods.contains(method)) {
        _selectedPaymentMethods.remove(method);
      } else {
        _selectedPaymentMethods.add(method);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Editar Motel' : 'Agregar Motel'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sección superior derecha (Botones de Habitaciones y Reseñas)
            Align(
              alignment: Alignment.centerRight,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () {
                      // TODO: Navegar a la vista de agregar/gestionar habitaciones
                    },
                    icon: const Icon(Icons.bed_outlined),
                    label: const Text('Agregar habitaciones'),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  // Solo mostramos "Ver reseña" si estamos en modo edición
                  if (widget.isEditing)
                    TextButton.icon(
                      onPressed: () {
                        // TODO: Navegar o abrir modal de reseñas
                      },
                      icon: const Icon(Icons.star_outline),
                      label: const Text('Ver reseña'),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.s2),

            // Formulario de datos básicos
            _buildTextField(
              controller: _emailController,
              label: 'Correo',
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: AppSpacing.s3),

            _buildTextField(
              controller: _nameController,
              label: 'Nombre',
              keyboardType: TextInputType.name,
            ),
            const SizedBox(height: AppSpacing.s3),

            _buildTextField(
              controller: _roomsController,
              label: '# Habitaciones',
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: AppSpacing.s3),

            _buildTextField(
              controller: _nitController,
              label: 'NIT',
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: AppSpacing.s3),

            _buildTextField(
              controller: _addressController,
              label: 'Dirección',
              keyboardType: TextInputType.streetAddress,
            ),
            const SizedBox(height: AppSpacing.s3),

            _buildTextField(
              controller: _phoneController,
              label: 'Teléfono',
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: AppSpacing.s5),

            // Sección de Métodos de Pago
            Text(
              'Métodos de pago',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.s2),
            Wrap(
              spacing: AppSpacing.s2,
              runSpacing: AppSpacing.s2,
              children: _availablePaymentMethods.map((method) {
                final isSelected = _selectedPaymentMethods.contains(method);
                return FilterChip(
                  label: Text(method),
                  selected: isSelected,
                  onSelected: (_) => _togglePaymentMethod(method),
                  selectedColor: Theme.of(context).colorScheme.primaryContainer,
                  checkmarkColor: Theme.of(
                    context,
                  ).colorScheme.onPrimaryContainer,
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.s5),

            // Sección de Imágenes
            Text('Imágenes', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.s2),
            InkWell(
              onTap: () {
                // TODO: Lógica para abrir selector de imágenes de la galería/cámara
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                height: 120,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: context.appColors.mediaFallback,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: context.appColors.border,
                    style: BorderStyle.solid,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_photo_alternate_outlined,
                      size: 40,
                      color: context.appColors.textSecondary,
                    ),
                    const SizedBox(height: AppSpacing.s1),
                    Text(
                      'Toca para agregar imágenes',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.appColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.s6),
          ],
        ),
      ),
      // Botón "Guardar" fijo en la parte inferior
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s4),
          child: AppButton(
            label: 'Guardar',
            onPressed: () {
              // TODO: Validar formulario y guardar/actualizar datos en Supabase
            },
          ),
        ),
      ),
    );
  }

  // Widget auxiliar para mantener el código limpio y estandarizar los campos de texto
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required TextInputType keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
    );
  }
}
