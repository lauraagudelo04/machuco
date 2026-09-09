import 'package:flutter/material.dart';
import '../../../core/design_system/design_system.dart';
import '../../../models/motel/motel_model.dart';

class OwnerMotelFormPage extends StatefulWidget {
  const OwnerMotelFormPage({
    super.key, 
    this.isEditing = false, 
    this.motel,
    this.ownerId, // Recibimos el ID del propietario actual
  });

  final bool isEditing;
  final Motel? motel;
  final String? ownerId;

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
  final _descriptionController = TextEditingController();
  final _generalLocationController = TextEditingController();

  final List<String> _selectedPaymentMethods = [];
  final List<String> _availablePaymentMethods = ['Efectivo', 'Tarjeta Crédito/Débito', 'Transferencia', 'Nequi / Daviplata'];
  
  List<String> _imageUrls = [];

  @override
  void initState() {
    super.initState();
    if (widget.isEditing && widget.motel != null) {
      _emailController.text = widget.motel!.email;
      _nameController.text = widget.motel!.name;
      _roomsController.text = widget.motel!.roomCount.toString();
      _nitController.text = widget.motel!.nit;
      _addressController.text = widget.motel!.address;
      _phoneController.text = widget.motel!.phone;
      // Solucionado el error de nulos usando el operador ?? ''
      _descriptionController.text = widget.motel!.description ?? '';         
      _generalLocationController.text = widget.motel!.generalLocation ?? '';   
      _selectedPaymentMethods.addAll(widget.motel!.paymentMethods);
      _imageUrls = List.from(widget.motel!.imageUrls);
    } else {
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
    _descriptionController.dispose();
    _generalLocationController.dispose();
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

  void _onSave() {
    final int roomCountParsed = int.tryParse(_roomsController.text.trim()) ?? 0;

    final Motel motelToSave = Motel(
      id: widget.isEditing && widget.motel != null ? widget.motel!.id : 'motel_${DateTime.now().millisecondsSinceEpoch}',
      ownerId: widget.ownerId ?? widget.motel?.ownerId ?? 'owner_1', // Incluido el ownerId requerido
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
      roomCount: roomCountParsed,
      nit: _nitController.text.trim(),
      address: _addressController.text.trim(),
      phone: _phoneController.text.trim(),
      description: _descriptionController.text.trim(),
      generalLocation: _generalLocationController.text.trim(),
      paymentMethods: _selectedPaymentMethods,
      imageUrls: _imageUrls.isEmpty ? ['https://via.placeholder.com/400'] : _imageUrls,
      basePrice: widget.isEditing && widget.motel != null ? widget.motel!.basePrice : 50000.0,
      isAvailable: widget.isEditing && widget.motel != null ? widget.motel!.isAvailable : true,
    );

    Navigator.pop(context, motelToSave);
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
              controller: _nameController,
              label: 'Nombre del establecimiento',
              keyboardType: TextInputType.name,
            ),
            const SizedBox(height: AppSpacing.s3),
            _buildTextField(
              controller: _descriptionController,
              label: 'Descripción',
              keyboardType: TextInputType.multiline,
              maxLines: 3, 
            ),
            const SizedBox(height: AppSpacing.s3),
            _buildTextField(
              controller: _emailController,
              label: 'Correo',
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: AppSpacing.s3),
            _buildTextField(
              controller: _phoneController,
              label: 'Teléfono',
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: AppSpacing.s3),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _roomsController,
                    label: '# Habitaciones',
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: AppSpacing.s3),
                Expanded(
                  child: _buildTextField(
                    controller: _nitController,
                    label: 'NIT',
                    keyboardType: TextInputType.text,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s3),
            _buildTextField(
              controller: _generalLocationController,
              label: 'Ubicación general (Ej: Norte, Centro)',
              keyboardType: TextInputType.text,
            ),
            const SizedBox(height: AppSpacing.s3),
            _buildTextField(
              controller: _addressController,
              label: 'Dirección exacta',
              keyboardType: TextInputType.streetAddress,
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
              onTap: () {
                setState(() {
                  _imageUrls.add('https://images.unsplash.com/photo-1566073771259-6a8506099945');
                });
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
                    Icon(Icons.add_photo_alternate_outlined, size: 40, color: context.appColors.textSecondary),
                    const SizedBox(height: AppSpacing.s1),
                    Text(
                      _imageUrls.isNotEmpty 
                          ? '${_imageUrls.length} imagen(es) cargada(s)' 
                          : 'Toca para agregar imágenes',
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
            onPressed: _onSave,
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required TextInputType keyboardType,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        alignLabelWithHint: maxLines > 1,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }
}