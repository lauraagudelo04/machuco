import 'package:flutter/material.dart';
import '../../../controllers/motel/motel_controller.dart';
import '../../../core/design_system/design_system.dart';
import '../../../models/motel/motel_model.dart';
import '../../../models/owner_management/owner.dart';
import '../../../utils/motel_form_validators.dart';
import '../../../widgets/motel/phone_number_field.dart';

/// Formulario del administrador del sistema para registrar o editar el motel
/// de cualquier propietario.
///
/// Guarda en el servidor con [MotelController.adminAddMotel] o
/// [MotelController.adminUpdateMotel] y, si sale bien, cierra devolviendo el
/// [Motel] guardado. Si el servidor lo rechaza (por ejemplo, NIT duplicado o
/// sin conexión) se queda abierto y muestra el motivo.
class AdminMotelFormPage extends StatefulWidget {
  const AdminMotelFormPage({
    super.key,
    required this.motelController,
    this.motel,
    this.ownerId,
    this.owners = const [],
  });

  final MotelController motelController;

  /// Motel a editar; `null` para registrar uno nuevo.
  final Motel? motel;

  /// Propietario al que se asigna el motel nuevo. Si es `null` el
  /// administrador lo elige de [owners].
  final String? ownerId;

  final List<Owner> owners;

  bool get isEditing => motel != null;

  @override
  State<AdminMotelFormPage> createState() => _AdminMotelFormPageState();
}

class _AdminMotelFormPageState extends State<AdminMotelFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _nameController = TextEditingController();
  final _roomsController = TextEditingController();
  final _nitController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _generalLocationController = TextEditingController();

  final List<String> _selectedPaymentMethods = [];
  final List<String> _availablePaymentMethods = [
    'Efectivo',
    'Tarjeta Crédito/Débito',
    'Transferencia',
    'Nequi / Daviplata',
  ];

  List<String> _imageUrls = [];
  bool _showPaymentMethodsError = false;
  bool _isSaving = false;
  String? _selectedOwnerId;

  /// Indicativo telefónico elegido; se concatena al número al guardar.
  String _selectedCallingCode = '+57';

  /// El selector de propietario solo aparece al registrar sin dueño fijo.
  bool get _choosesOwner => !widget.isEditing && widget.ownerId == null;

  @override
  void initState() {
    super.initState();
    final motel = widget.motel;
    if (motel != null) {
      _emailController.text = motel.email;
      _nameController.text = motel.name;
      _roomsController.text = motel.roomCount.toString();
      _nitController.text = motel.nit;
      _addressController.text = motel.address;
      _setPhoneFromSaved(motel.phone);
      _descriptionController.text = motel.description ?? '';
      _generalLocationController.text = motel.generalLocation ?? '';
      _selectedPaymentMethods.addAll(motel.paymentMethods);
      _imageUrls = List.from(motel.imageUrls);
      _selectedOwnerId = motel.ownerId;
    } else {
      _selectedPaymentMethods.add('Efectivo');
      _selectedOwnerId = widget.ownerId;
    }
  }

  /// Separa el indicativo del número cuando el teléfono se guardó
  /// como `+57 3001234567`. Si no trae indicativo, se deja +57.
  void _setPhoneFromSaved(String phone) {
    final spaceIndex = phone.indexOf(' ');
    if (phone.startsWith('+') && spaceIndex > 0) {
      _selectedCallingCode = phone.substring(0, spaceIndex);
      _phoneController.text = phone.substring(spaceIndex + 1);
    } else {
      _phoneController.text = phone;
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
      if (_selectedPaymentMethods.isNotEmpty) {
        _showPaymentMethodsError = false;
      }
    });
  }

  String? _trimmedOrNull(TextEditingController controller) {
    final text = controller.text.trim();
    return text.isEmpty ? null : text;
  }

  Future<void> _onSave() async {
    if (_isSaving) return;

    final isFormValid = _formKey.currentState?.validate() ?? false;
    final paymentMethodsError = MotelFormValidators.validatePaymentMethods(
      _selectedPaymentMethods,
    );
    setState(() => _showPaymentMethodsError = paymentMethodsError != null);

    if (!isFormValid || paymentMethodsError != null) return;

    final ownerId = _selectedOwnerId;
    if (ownerId == null || ownerId.isEmpty) return;

    setState(() => _isSaving = true);

    final original = widget.motel;
    final motelToSave = Motel(
      // Al registrar, el id definitivo lo asigna el servidor.
      id: original?.id ?? '',
      ownerId: ownerId,
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
      roomCount: int.parse(_roomsController.text.trim()),
      nit: _nitController.text.trim(),
      address: _addressController.text.trim(),
      phone: '$_selectedCallingCode ${_phoneController.text.trim()}',
      description: _trimmedOrNull(_descriptionController),
      generalLocation: _trimmedOrNull(_generalLocationController),
      paymentMethods: List.of(_selectedPaymentMethods),
      imageUrls: _imageUrls.isEmpty
          ? ['https://via.placeholder.com/400']
          : _imageUrls,
      isAvailable: original?.isAvailable ?? true,
    );

    try {
      final saved = widget.isEditing
          ? await widget.motelController.adminUpdateMotel(motelToSave)
          : await widget.motelController.adminAddMotel(motelToSave);
      if (mounted) Navigator.pop(context, saved);
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final paymentMethodsError = _showPaymentMethodsError
        ? MotelFormValidators.validatePaymentMethods(_selectedPaymentMethods)
        : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Editar Motel' : 'Agregar Motel'),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.s4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.s2),
              if (_choosesOwner) ...[
                DropdownButtonFormField<String>(
                  initialValue: _selectedOwnerId,
                  isExpanded: true,
                  decoration: _inputDecoration('Propietario'),
                  items: [
                    for (final owner in widget.owners)
                      DropdownMenuItem(
                        value: owner.id,
                        child: Text(
                          owner.fullName,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (value) =>
                      setState(() => _selectedOwnerId = value),
                  validator: (value) => value == null || value.isEmpty
                      ? 'Selecciona el propietario del motel'
                      : null,
                ),
                const SizedBox(height: AppSpacing.s3),
              ],
              _buildTextField(
                controller: _nameController,
                label: 'Nombre del establecimiento',
                keyboardType: TextInputType.name,
                validator: MotelFormValidators.validateName,
              ),
              const SizedBox(height: AppSpacing.s3),
              _buildTextField(
                controller: _descriptionController,
                label: 'Descripción',
                keyboardType: TextInputType.multiline,
                maxLines: 3,
                validator: MotelFormValidators.validateDescription,
              ),
              const SizedBox(height: AppSpacing.s3),
              _buildTextField(
                controller: _emailController,
                label: 'Correo',
                keyboardType: TextInputType.emailAddress,
                validator: MotelFormValidators.validateEmail,
              ),
              const SizedBox(height: AppSpacing.s3),
              PhoneNumberField(
                controller: _phoneController,
                initialCallingCode: _selectedCallingCode,
                onCallingCodeChanged: (value) =>
                    setState(() => _selectedCallingCode = value),
              ),
              const SizedBox(height: AppSpacing.s3),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: _roomsController,
                      label: '# Habitaciones',
                      keyboardType: TextInputType.number,
                      validator: MotelFormValidators.validateRoomCount,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s3),
                  Expanded(
                    child: _buildTextField(
                      controller: _nitController,
                      label: 'NIT',
                      keyboardType: TextInputType.text,
                      validator: MotelFormValidators.validateNit,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s3),
              _buildTextField(
                controller: _generalLocationController,
                label: 'Ubicación general (Ej: Norte, Centro)',
                keyboardType: TextInputType.text,
                validator: MotelFormValidators.validateGeneralLocation,
              ),
              const SizedBox(height: AppSpacing.s3),
              _buildTextField(
                controller: _addressController,
                label: 'Dirección exacta',
                keyboardType: TextInputType.streetAddress,
                validator: MotelFormValidators.validateAddress,
              ),
              const SizedBox(height: AppSpacing.s5),
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
                    selectedColor: Theme.of(
                      context,
                    ).colorScheme.primaryContainer,
                    checkmarkColor: Theme.of(
                      context,
                    ).colorScheme.onPrimaryContainer,
                  );
                }).toList(),
              ),
              if (paymentMethodsError != null)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.s1),
                  child: Text(
                    paymentMethodsError,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              const SizedBox(height: AppSpacing.s5),
              Text('Imágenes', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.s2),
              InkWell(
                onTap: () {
                  setState(() {
                    _imageUrls.add(
                      'https://images.unsplash.com/photo-1566073771259-6a8506099945',
                    );
                  });
                },
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: Container(
                  height: 120,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: context.appColors.mediaFallback,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: context.appColors.border),
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
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s4),
          child: AppButton(
            label: 'Guardar',
            loading: _isSaving,
            onPressed: _isSaving ? null : _onSave,
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, {int maxLines = 1}) {
    return InputDecoration(
      labelText: label,
      alignLabelWithHint: maxLines > 1,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s4,
        vertical: AppSpacing.s3,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required TextInputType keyboardType,
    int maxLines = 1,
    FormFieldValidator<String>? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      decoration: _inputDecoration(label, maxLines: maxLines),
    );
  }
}
