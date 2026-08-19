import 'package:flutter/material.dart';

import 'package:machuco/core/design_system/components/app_button.dart';
import 'package:machuco/core/design_system/components/app_card.dart';
import 'package:machuco/core/design_system/components/app_text_field.dart';
import 'package:machuco/core/design_system/theme/app_theme_extensions.dart';
import 'package:machuco/core/design_system/tokens/app_colors.dart';
import 'package:machuco/core/design_system/tokens/app_spacing.dart';

import 'owner_models.dart';
import 'owner_summary.dart';

const _minimumFullNameLength = 3;
const _compactWidthBreakpoint = 360.0;
const _formMaxWidth = 520.0;

/// Modo en el que se abre el formulario, derivado de los datos recibidos.
enum OwnerFormMode { create, edit }

/// Formulario de creación y edición de un propietario de moteles.
///
/// Si [initialData] es `null` el formulario crea un propietario nuevo; en caso
/// contrario precarga los datos recibidos y solo permite ajustar el teléfono,
/// porque el resto de la información identifica legalmente al propietario.
///
/// Al cerrarse devuelve el [OwnerFormData] resultante, o `null` si el usuario
/// canceló.
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

  // Al crear, el formulario cede su lugar a un resumen de lo registrado: deja
  // de ser editable y confirma exactamente qué información quedó guardada.
  OwnerFormData? _createdOwner;

  OwnerFormMode get _mode =>
      widget.initialData == null ? OwnerFormMode.create : OwnerFormMode.edit;

  bool get _isEditing => _mode == OwnerFormMode.edit;

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

  /// En edición solo el teléfono es editable, así que los demás campos no se
  /// validan: no pueden haber cambiado desde esta pantalla.
  void _updateErrors() {
    _fullNameError = _isEditing
        ? null
        : _validateFullName(_fullNameController.text);
    _documentNumberError = _isEditing
        ? null
        : _validateDocumentNumber(
            _documentNumberController.text,
            _documentType,
          );
    _emailError = _isEditing ? null : _validateEmail(_emailController.text);
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

  OwnerFormData _buildFormData() {
    final address = _addressController.text.trim();
    return OwnerFormData(
      fullName: _fullNameController.text.trim(),
      documentType: _documentType,
      documentNumber: _documentNumberController.text.trim(),
      email: _emailController.text.trim(),
      phone: _phoneController.text.trim(),
      address: address.isEmpty ? null : address,
      isActive: _isActive,
    );
  }

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

    // Todavía no existe capa de datos: el resultado se devuelve a la pantalla
    // anterior y la confirmación es únicamente visual.
    final owner = _buildFormData();
    if (_isEditing) {
      Navigator.of(context).pop(owner);
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _createdOwner = owner);
  }

  void _cancelForm() => Navigator.of(context).maybePop();

  void _finishCreation() => Navigator.of(context).pop(_createdOwner);

  String get _title {
    if (_createdOwner != null) return 'Propietario creado';
    return _isEditing ? 'Editar propietario' : 'Nuevo propietario';
  }

  @override
  Widget build(BuildContext context) {
    final createdOwner = _createdOwner;
    return PopScope(
      // Tras crear, el gesto de volver debe entregar el propietario registrado
      // en lugar de descartarlo.
      canPop: createdOwner == null,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _finishCreation();
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: createdOwner == null,
          title: Text(_title),
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
                    children: createdOwner == null
                        ? _buildFormFields()
                        : [_OwnerCreatedSummary(owner: createdOwner)],
                  ),
                ),
              );
            },
          ),
        ),
        bottomNavigationBar: createdOwner == null
            ? _OwnerFormActions(
                mode: _mode,
                onSubmit: _submitForm,
                onCancel: _cancelForm,
              )
            : _OwnerCreatedActions(onFinish: _finishCreation),
      ),
    );
  }

  List<Widget> _buildFormFields() {
    return [
      if (_isEditing) ...[
        const _EditingNotice(),
        const SizedBox(height: AppSpacing.s5),
      ],
      _FormSection(
        title: 'Identificación',
        children: [
          AppTextField(
            label: 'Nombre completo',
            controller: _fullNameController,
            hint: 'Ej.: Laura Gómez Restrepo',
            errorText: _fullNameError,
            enabled: !_isEditing,
            keyboardType: TextInputType.name,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.name],
            onChanged: (_) => _revalidateAfterChange(),
            onSubmitted: (_) => _focusNextField(),
          ),
          const SizedBox(height: AppSpacing.s4),
          _DocumentTypeSelector(
            selectedType: _documentType,
            onSelected: _isEditing ? null : _selectDocumentType,
          ),
          const SizedBox(height: AppSpacing.s4),
          AppTextField(
            label: 'Número de documento',
            controller: _documentNumberController,
            hint: 'Ej.: ${_documentType.example}',
            errorText: _documentNumberError,
            enabled: !_isEditing,
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
            enabled: !_isEditing,
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
            textInputAction: _isEditing
                ? TextInputAction.done
                : TextInputAction.next,
            autofillHints: const [AutofillHints.telephoneNumber],
            onChanged: (_) => _revalidateAfterChange(),
            onSubmitted: (_) {
              if (_isEditing) {
                _submitForm();
              } else {
                _focusNextField();
              }
            },
          ),
          const SizedBox(height: AppSpacing.s4),
          AppTextField(
            label: 'Dirección (opcional)',
            controller: _addressController,
            hint: 'Ej.: Calle 10 # 43-25',
            enabled: !_isEditing,
            keyboardType: TextInputType.streetAddress,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.fullStreetAddress],
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
            // En edición el estado se cambia desde la lista de propietarios.
            onChanged: _isEditing ? null : _toggleActiveState,
          ),
        ],
      ),
    ];
  }
}

/// Aviso de por qué la mayoría de los campos están bloqueados en edición.
class _EditingNotice extends StatelessWidget {
  const _EditingNotice();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            size: 20,
            color: context.appColors.textSecondary,
          ),
          const SizedBox(width: AppSpacing.s3),
          Expanded(
            child: Text(
              'Solo puedes actualizar el teléfono. Los demás datos identifican '
              'al propietario y se muestran como referencia.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: context.appColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Confirmación con el resumen de la información que quedó registrada.
class _OwnerCreatedSummary extends StatelessWidget {
  const _OwnerCreatedSummary({required this.owner});

  final OwnerFormData owner;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          liveRegion: true,
          child: Column(
            children: [
              const Icon(
                Icons.check_circle_outline,
                size: 48,
                color: AppColors.available,
              ),
              const SizedBox(height: AppSpacing.s3),
              Text(
                'Propietario creado correctamente',
                style: textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.s2),
              Text(
                'Esta es la información que quedó registrada.',
                style: textTheme.bodyMedium?.copyWith(
                  color: context.appColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.s6),
        OwnerSummary(owner: owner),
      ],
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

  /// `null` deja el selector en solo lectura.
  final ValueChanged<DocumentType>? onSelected;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final onSelected = this.onSelected;
    // En solo lectura solo se conserva el tipo seleccionado: las demás opciones
    // no aportan nada si no se pueden elegir.
    final documentTypes = onSelected == null
        ? [selectedType]
        : DocumentType.values;
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
            for (final documentType in documentTypes)
              Tooltip(
                message: documentType.description,
                child: ChoiceChip(
                  label: Text(documentType.shortLabel),
                  selected: documentType == selectedType,
                  onSelected: onSelected == null
                      ? null
                      : (_) => onSelected(documentType),
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

  /// `null` deja el interruptor en solo lectura.
  final ValueChanged<bool>? onChanged;

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
    return _ActionsBar(
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
    );
  }
}

class _OwnerCreatedActions extends StatelessWidget {
  const _OwnerCreatedActions({required this.onFinish});

  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    return _ActionsBar(
      children: [
        Expanded(
          child: AppButton(label: 'Ir a propietarios', onPressed: onFinish),
        ),
      ],
    );
  }
}

class _ActionsBar extends StatelessWidget {
  const _ActionsBar({required this.children});

  final List<Widget> children;

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
        child: Row(children: children),
      ),
    );
  }
}
