import 'package:flutter/material.dart';
import '../../../core/design_system/design_system.dart';
import '../../../models/motel/motel_model.dart'; // Importamos el modelo

class OwnerMotelFormPage extends StatefulWidget {
  // Ahora recibimos opcionalmente el modelo del motel
  const OwnerMotelFormPage({
    super.key, 
    this.isEditing = false, 
    this.motel,
  });

  final bool isEditing;
  final Motel? motel; // Puede ser nulo porque al crear desde cero no existe

  @override
  State<OwnerMotelFormPage> createState() => _OwnerMotelFormPageState();
}

class _OwnerMotelFormPageState extends State<OwnerMotelFormPage> {
  final _emailController = TextEditingController();
  final _nameController = TextEditingController();
  final _roomsController = TextEditingController();
  final _nitController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();

  // Quitamos 'Efectivo' por defecto de aquí, lo manejaremos en el initState
  final List<String> _selectedPaymentMethods = [];
  final List<String> _availablePaymentMethods = ['Efectivo', 'Tarjeta Crédito/Débito', 'Transferencia', 'Nequi / Daviplata'];

  @override
  void initState() {
    super.initState();
    // Si estamos editando y el motel no es nulo, cargamos sus datos
    if (widget.isEditing && widget.motel != null) {
      _emailController.text = widget.motel!.email;
      _nameController.text = widget.motel!.name;
      _roomsController.text = widget.motel!.roomCount.toString();
      _nitController.text = widget.motel!.nit;
      _addressController.text = widget.motel!.address;
      _phoneController.text = widget.motel!.phone;
      _selectedPaymentMethods.addAll(widget.motel!.paymentMethods);
    } else {
      // Si estamos creando uno nuevo, dejamos un valor por defecto
      _selectedPaymentMethods.add('Efectivo');
    }
  }

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
            const SizedBox(height: AppSpacing.s2),

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

            Text('Métodos de pago', style: Theme.of(context).textTheme.titleMedium),
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
                  checkmarkColor: Theme.of(context).colorScheme.onPrimaryContainer,
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.s5),

            Text('Imágenes', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.s2),
            InkWell(
              onTap: () {},
              borderRadius: BorderRadius.circular(12),
              child: Container(
                height: 120,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: context.appColors.mediaFallback ?? Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: context.appColors.border ?? Colors.grey.shade400,
                    style: BorderStyle.solid,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_photo_alternate_outlined, size: 40, color: context.appColors.textSecondary),
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
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s4),
          child: AppButton(
            label: 'Guardar',
            onPressed: () {
              // Aquí podrías construir un nuevo objeto Motel con los datos de los controladores
              // y pasarlo a un método del controlador para guardarlo o actualizarlo.
            },
          ),
        ),
      ),
    );
  }

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
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }
}