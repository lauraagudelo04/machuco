import 'package:flutter/material.dart';

import 'package:machuco/core/design_system/components/app_button.dart';
import 'package:machuco/core/design_system/components/app_card.dart';
import 'package:machuco/core/design_system/components/app_text_field.dart';
import 'package:machuco/core/design_system/theme/app_theme_extensions.dart';
import 'package:machuco/core/design_system/tokens/app_spacing.dart';

const _minimumFullNameLength = 3;
const _compactWidthBreakpoint = 360.0;
const _formMaxWidth = 520.0;

/// Tipos de documento admitidos para identificar a un propietario.
///
/// Cada valor define cómo se valida y cómo se captura el número asociado, para
/// evitar cadenas libres y condicionales dispersos en la vista.
enum DocumentType {
  citizenshipCard('CC', 'Cédula de ciudadanía', r'^\d{6,10}$', '1020304050'),
  foreignerCard('CE', 'Cédula de extranjería', r'^\d{6,12}$', '345678'),
  taxId(
    'NIT',
    'Número de identificación tributaria',
    r'^\d{9,10}(-\d)?$',
    '900123456-7',
  ),
  passport('Pasaporte', 'Pasaporte', r'^[A-Za-z0-9]{6,12}$', 'AV123456');

  const DocumentType(
    this.shortLabel,
    this.description,
    this.pattern,
    this.example,
  );

  final String shortLabel;
  final String description;
  final String pattern;
  final String example;

  TextInputType get keyboardType => switch (this) {
    DocumentType.passport => TextInputType.text,
    _ => TextInputType.number,
  };

  bool acceptsDocumentNumber(String value) => RegExp(pattern).hasMatch(value);
}

/// Modo en el que se abre el formulario, derivado de los datos recibidos.
enum OwnerFormMode { create, edit }

/// Datos con los que se precarga el formulario en modo edición.
///
/// Es una representación de presentación temporal: cuando exista la capa de
/// modelos debe reemplazarse por el modelo de dominio correspondiente.
@immutable
class OwnerFormData {
  const OwnerFormData({
    required this.fullName,
    required this.documentType,
    required this.documentNumber,
    required this.email,
    required this.phone,
    this.address,
    this.isActive = true,
  });

  final String fullName;
  final DocumentType documentType;
  final String documentNumber;
  final String email;
  final String phone;
  final String? address;
  final bool isActive;
}

/// Formulario de creación y edición de un propietario de moteles.
///
/// Si [initialData] es `null` el formulario crea un propietario nuevo; en caso
/// contrario precarga los datos recibidos y guarda cambios sobre ellos.
class OwnerFormPage extends StatefulWidget {
  const OwnerFormPage({super.key, this.initialData});

  final OwnerFormData? initialData;

  @override
  State<OwnerFormPage> createState() => _OwnerFormPageState();
}

class _OwnerFormPageState extends State<OwnerFormPage> {
  late final TextEditingController _fullNameController;
  late final TextEditingController _documentNumberController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _addressController;

  late DocumentType _documentType;
  late bool _isActive;

  // `AppTextField` expone `errorText` y no un `validator`, por lo que el estado
  // de validación se conserva aquí. Los errores aparecen tras el primer envío y
  // desde ese momento el campo se revalida mientras el usuario lo corrige.
  bool _hasAttemptedSubmit = false;
  String? _fullNameError;
  String? _documentNumberError;
  String? _emailError;
  String? _phoneError;

  OwnerFormMode get _mode =>
      widget.initialData == null ? OwnerFormMode.create : OwnerFormMode.edit;

  bool get _hasErrors =>
      _fullNameError != null ||
      _documentNumberError != null ||
      _emailError != null ||
      _phoneError != null;

  @override
  void initState() {
    super.initState();
    final initialData = widget.initialData;
    _fullNameController = TextEditingController(text: initialData?.fullName);
    _documentNumberController = TextEditingController(
      text: initialData?.documentNumber,
    );
    _emailController = TextEditingController(text: initialData?.email);
    _phoneController = TextEditingController(text: initialData?.phone);
    _addressController = TextEditingController(text: initialData?.address);
    _documentType = initialData?.documentType ?? DocumentType.citizenshipCard;
    _isActive = initialData?.isActive ?? true;
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _documentNumberController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  static String? _validateFullName(String value) {
    final fullName = value.trim();
    if (fullName.isEmpty) return 'Ingresa el nombre completo.';
    if (fullName.length < _minimumFullNameLength) {
      return 'El nombre debe tener al menos $_minimumFullNameLength caracteres.';
    }
    return null;
  }

  static String? _validateDocumentNumber(
    String value,
    DocumentType documentType,
  ) {
    final documentNumber = value.trim();
    if (documentNumber.isEmpty) return 'Ingresa el número de documento.';
    if (!documentType.acceptsDocumentNumber(documentNumber)) {
      return 'Número no válido para ${documentType.shortLabel}. Ejemplo: ${documentType.example}.';
    }
    return null;
  }

  static String? _validateEmail(String value) {
    final email = value.trim();
    if (email.isEmpty) return 'Ingresa el correo electrónico.';
    if (!RegExp(r'^[\w.+-]+@[\w-]+(\.[\w-]+)+$').hasMatch(email)) {
      return 'Ingresa un correo válido, por ejemplo nombre@dominio.com.';
    }
    return null;
  }

  static String? _validatePhone(String value) {
    if (value.trim().isEmpty) return 'Ingresa el teléfono.';
    final phone = value.replaceAll(RegExp(r'[\s\-()]'), '');
    if (!RegExp(r'^\+?\d{7,15}$').hasMatch(phone)) {
      return 'Ingresa un teléfono válido, por ejemplo +57 300 123 4567.';
    }
    return null;
  }

  void _updateErrors() {
    _fullNameError = _validateFullName(_fullNameController.text);
    _documentNumberError = _validateDocumentNumber(
      _documentNumberController.text,
      _documentType,
    );
    _emailError = _validateEmail(_emailController.text);
    _phoneError = _validatePhone(_phoneController.text);
  }

  void _revalidateAfterChange() {
    if (!_hasAttemptedSubmit) return;
    setState(_updateErrors);
  }

  void _selectDocumentType(DocumentType documentType) {
    if (documentType == _documentType) return;
    setState(() {
      _documentType = documentType;
      if (_hasAttemptedSubmit) _updateErrors();
    });
  }

  void _toggleActiveState(bool isActive) =>
      setState(() => _isActive = isActive);

  void _focusNextField() => FocusScope.of(context).nextFocus();

  void _submitForm() {
    setState(() {
      _hasAttemptedSubmit = true;
      _updateErrors();
    });

    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    if (_hasErrors) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Revisa los campos marcados antes de guardar.'),
        ),
      );
      return;
    }

    // Todavía no existe capa de datos: la confirmación es únicamente visual.
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          _mode == OwnerFormMode.create
              ? 'Propietario creado correctamente.'
              : 'Cambios guardados correctamente.',
        ),
      ),
    );
  }

  void _cancelForm() => Navigator.of(context).maybePop();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _mode == OwnerFormMode.create
              ? 'Nuevo propietario'
              : 'Editar propietario',
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontalPadding =
                constraints.maxWidth < _compactWidthBreakpoint
                ? AppSpacing.screenCompact
                : AppSpacing.screen;
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _formMaxWidth),
                child: ListView(
                  padding: EdgeInsets.symmetric(
                    horizontal: horizontalPadding,
                    vertical: AppSpacing.s5,
                  ),
                  children: [
                    _FormSection(
                      title: 'Identificación',
                      children: [
                        AppTextField(
                          label: 'Nombre completo',
                          controller: _fullNameController,
                          hint: 'Ej.: Laura Gómez Restrepo',
                          errorText: _fullNameError,
                          keyboardType: TextInputType.name,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.name],
                          onChanged: (_) => _revalidateAfterChange(),
                          onSubmitted: (_) => _focusNextField(),
                        ),
                        const SizedBox(height: AppSpacing.s4),
                        _DocumentTypeSelector(
                          selectedType: _documentType,
                          onSelected: _selectDocumentType,
                        ),
                        const SizedBox(height: AppSpacing.s4),
                        AppTextField(
                          label: 'Número de documento',
                          controller: _documentNumberController,
                          hint: 'Ej.: ${_documentType.example}',
                          errorText: _documentNumberError,
                          keyboardType: _documentType.keyboardType,
                          textInputAction: TextInputAction.next,
                          onChanged: (_) => _revalidateAfterChange(),
                          onSubmitted: (_) => _focusNextField(),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.s6),
                    _FormSection(
                      title: 'Contacto',
                      children: [
                        AppTextField(
                          label: 'Correo electrónico',
                          controller: _emailController,
                          hint: 'nombre@dominio.com',
                          errorText: _emailError,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.email],
                          onChanged: (_) => _revalidateAfterChange(),
                          onSubmitted: (_) => _focusNextField(),
                        ),
                        const SizedBox(height: AppSpacing.s4),
                        AppTextField(
                          label: 'Teléfono',
                          controller: _phoneController,
                          hint: '+57 300 123 4567',
                          errorText: _phoneError,
                          keyboardType: TextInputType.phone,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.telephoneNumber],
                          onChanged: (_) => _revalidateAfterChange(),
                          onSubmitted: (_) => _focusNextField(),
                        ),
                        const SizedBox(height: AppSpacing.s4),
                        AppTextField(
                          label: 'Dirección (opcional)',
                          controller: _addressController,
                          hint: 'Ej.: Calle 10 # 43-25',
                          keyboardType: TextInputType.streetAddress,
                          textInputAction: TextInputAction.done,
                          autofillHints: const [
                            AutofillHints.fullStreetAddress,
                          ],
                          onSubmitted: (_) => _submitForm(),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.s6),
                    _FormSection(
                      title: 'Estado',
                      children: [
                        _ActiveStateField(
                          isActive: _isActive,
                          onChanged: _toggleActiveState,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: _OwnerFormActions(
        mode: _mode,
        onSubmit: _submitForm,
        onCancel: _cancelForm,
      ),
    );
  }
}

class _FormSection extends StatelessWidget {
  const _FormSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.s3),
        ...children,
      ],
    );
  }
}

class _DocumentTypeSelector extends StatelessWidget {
  const _DocumentTypeSelector({
    required this.selectedType,
    required this.onSelected,
  });

  final DocumentType selectedType;
  final ValueChanged<DocumentType> onSelected;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tipo de documento',
          style: textTheme.labelMedium?.copyWith(
            color: context.appColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.s2),
        Wrap(
          spacing: AppSpacing.s2,
          runSpacing: AppSpacing.s2,
          children: [
            for (final documentType in DocumentType.values)
              Tooltip(
                message: documentType.description,
                child: ChoiceChip(
                  label: Text(documentType.shortLabel),
                  selected: documentType == selectedType,
                  onSelected: (_) => onSelected(documentType),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.s2),
        Text(
          selectedType.description,
          style: textTheme.bodySmall?.copyWith(
            color: context.appColors.textMuted,
          ),
        ),
      ],
    );
  }
}

class _ActiveStateField extends StatelessWidget {
  const _ActiveStateField({required this.isActive, required this.onChanged});

  final bool isActive;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return AppCard(
      child: SwitchListTile(
        value: isActive,
        onChanged: onChanged,
        contentPadding: EdgeInsets.zero,
        title: Text('Propietario activo', style: textTheme.bodyLarge),
        subtitle: Text(
          isActive
              ? 'Puede administrar sus moteles y recibir reservas.'
              : 'No puede administrar sus moteles ni recibir reservas.',
          style: textTheme.bodySmall?.copyWith(
            color: context.appColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _OwnerFormActions extends StatelessWidget {
  const _OwnerFormActions({
    required this.mode,
    required this.onSubmit,
    required this.onCancel,
  });

  final OwnerFormMode mode;
  final VoidCallback onSubmit;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.appColors.canvas,
        border: Border(top: BorderSide(color: context.appColors.border)),
      ),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.all(AppSpacing.s4),
        child: Row(
          children: [
            Expanded(
              child: AppButton(
                label: 'Cancelar',
                variant: AppButtonVariant.secondary,
                onPressed: onCancel,
              ),
            ),
            const SizedBox(width: AppSpacing.s3),
            Expanded(
              flex: 2,
              child: AppButton(
                label: mode == OwnerFormMode.create
                    ? 'Crear propietario'
                    : 'Guardar cambios',
                onPressed: onSubmit,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
