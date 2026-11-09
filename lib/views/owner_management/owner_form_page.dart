import 'dart:async';

import 'package:flutter/material.dart';

import 'package:machuco/core/design_system/components/app_button.dart';
import 'package:machuco/core/design_system/components/app_card.dart';
import 'package:machuco/core/design_system/components/app_text_field.dart';
import 'package:machuco/core/design_system/theme/app_theme_extensions.dart';
import 'package:machuco/core/design_system/tokens/app_colors.dart';
import 'package:machuco/core/design_system/tokens/app_spacing.dart';

import 'package:machuco/controllers/owner_management/owner_controller.dart';
import 'package:machuco/models/auth/country_phone_code.dart';
import 'package:machuco/models/owner_management/document_type.dart';
import 'package:machuco/models/owner_management/owner.dart';
import 'package:machuco/repositories/owner/owner_cloud_repository.dart';
import 'package:machuco/widgets/form/app_phone_field.dart';

import 'owner_summary.dart';

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
/// Guarda a través de [controller] y al cerrarse devuelve el [Owner]
/// resultante, o `null` si el usuario canceló.
class OwnerFormPage extends StatefulWidget {
  const OwnerFormPage({super.key, required this.controller, this.initialData});

  final OwnerController controller;
  final Owner? initialData;

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

  // Estado inicial que elige el administrador al crear la cuenta. En edición
  // el estado se cambia desde la lista de propietarios.
  bool _pendingApproval = false;

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
  Owner? _createdOwner;

  /// Contraseña temporal de la cuenta recién creada: se muestra una sola vez.
  String? _temporaryPassword;

  // Mientras la persistencia está en curso se bloquean los botones para evitar
  // envíos duplicados.
  bool _isSaving = false;

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
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadCatalogs());
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

  /// En edición se validan los datos editables; el correo no se toca porque
  /// identifica la cuenta de Firebase Auth.
  void _updateErrors() {
    _fullNameError = OwnerController.validateFullName(_fullNameController.text);
    _documentNumberError = OwnerController.validateDocumentNumber(
      _documentNumberController.text,
      _documentType,
    );
    _emailError = _isEditing
        ? null
        : OwnerController.validateEmail(_emailController.text);
    _phoneError = widget.controller.validatePhone(_phoneController.text);
  }

  /// Carga los maestros que alimentan el formulario (tipos de documento e
  /// indicativos) y alinea la selección con los datos existentes.
  ///
  /// La caché local pinta de inmediato; el refresco de Supabase se lanza en
  /// segundo plano para que abrir el formulario sin conexión no espere a la
  /// red.
  Future<void> _loadCatalogs({bool forceRefresh = false}) async {
    await widget.controller.loadDocumentTypes();
    if (!mounted) return;
    _applyDocumentTypes();

    await _loadCountryCodes(forceRefresh: forceRefresh);
    // Refresca el maestro sin bloquear el formulario.
    unawaited(_refreshDocumentTypes());
  }

  Future<void> _refreshDocumentTypes() async {
    await widget.controller.loadDocumentTypes(forceRefresh: true);
    if (!mounted) return;
    _applyDocumentTypes();
  }

  void _applyDocumentTypes() {
    final types = widget.controller.documentTypes;
    if (types.isNotEmpty && !types.contains(_documentType)) {
      setState(() => _documentType = types.first);
    }
  }

  /// Carga el maestro de indicativos y alinea el selector con los datos
  /// existentes. Las filas antiguas guardaban el teléfono concatenado
  /// (`+57 300 123 4567`), así que aquí se separa el indicativo la primera vez.
  Future<void> _loadCountryCodes({bool forceRefresh = false}) async {
    final controller = widget.controller;
    await controller.loadCountryCodes(forceRefresh: forceRefresh);
    if (!mounted) return;

    final initialData = widget.initialData;
    var phone = _phoneController.text;
    var code = controller.countryCodeForDialCode(initialData?.countryCode);

    if (initialData != null && initialData.countryCode == null) {
      final raw = initialData.phone.trim();
      if (raw.startsWith('+')) {
        CountryPhoneCode? match;
        for (final candidate in controller.countryCodes) {
          if (raw.startsWith(candidate.dialCode) &&
              (match == null ||
                  candidate.dialCode.length > match.dialCode.length)) {
            match = candidate;
          }
        }
        if (match != null) {
          code = match;
          phone = raw.substring(match.dialCode.length).trim();
        }
      }
    }

    // Al crear, retoma el indicativo usado la última vez en este dispositivo.
    if (initialData == null) {
      final lastUsed = await controller.lastUsedCountryCode();
      if (lastUsed != null) code = lastUsed;
    }

    if (code != null) controller.selectCountryCode(code);
    if (phone != _phoneController.text) {
      _phoneController.text = phone;
    }
    setState(() {
      if (_hasAttemptedSubmit) _updateErrors();
    });
  }

  void _selectCountryCode(CountryPhoneCode code) {
    setState(() {
      widget.controller.selectCountryCode(code);
      if (_hasAttemptedSubmit) _updateErrors();
    });
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

  void _selectInitialStatus(bool pendingApproval) =>
      setState(() => _pendingApproval = pendingApproval);

  void _focusNextField() => FocusScope.of(context).nextFocus();

  Future<void> _submitForm() async {
    if (_isSaving) return;
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

    FocusScope.of(context).unfocus();
    setState(() => _isSaving = true);

    final initialData = widget.initialData;
    final selectedCountryCode = widget.controller.selectedCountryCode;
    final countryCode = selectedCountryCode?.dialCode;
    final countryName = selectedCountryCode?.countryName;
    Owner? saved;
    CreatedOwner? created;
    if (initialData != null) {
      saved = await widget.controller.updateOwner(
        initialData.id,
        fullName: _fullNameController.text.trim(),
        documentType: _documentType,
        documentNumber: _documentNumberController.text.trim(),
        phone: _phoneController.text.trim(),
        countryCode: countryCode,
        countryName: countryName,
        address: _addressController.text.trim().isEmpty
            ? null
            : _addressController.text.trim(),
      );
    } else {
      final address = _addressController.text.trim();
      created = await widget.controller.createOwner(
        fullName: _fullNameController.text.trim(),
        documentType: _documentType,
        documentNumber: _documentNumberController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        countryCode: countryCode,
        countryName: countryName,
        address: address.isEmpty ? null : address,
        pendingApproval: _pendingApproval,
      );
      saved = created?.owner;
    }

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (saved == null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            widget.controller.lastError ??
                'No se pudo guardar el propietario. Intenta de nuevo.',
          ),
        ),
      );
      return;
    }

    // Recuerda el indicativo para la próxima creación en este dispositivo.
    if (selectedCountryCode != null) {
      await widget.controller.saveLastCountryCode(selectedCountryCode.id);
    }

    if (!mounted) return;

    if (initialData != null) {
      Navigator.of(context).pop(saved);
      return;
    }

    setState(() {
      _createdOwner = saved;
      _temporaryPassword = created?.temporaryPassword;
    });
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
                        : [
                            _OwnerCreatedSummary(
                              owner: createdOwner,
                              temporaryPassword: _temporaryPassword,
                            ),
                          ],
                  ),
                ),
              );
            },
          ),
        ),
        bottomNavigationBar: createdOwner == null
            ? _OwnerFormActions(
                mode: _mode,
                isSaving: _isSaving,
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
            keyboardType: TextInputType.name,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.name],
            onChanged: (_) => _revalidateAfterChange(),
            onSubmitted: (_) => _focusNextField(),
          ),
          const SizedBox(height: AppSpacing.s4),
          _DocumentTypeSelector(
            selectedType: _documentType,
            documentTypes: widget.controller.documentTypes,
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
            // El correo identifica la cuenta de Firebase Auth: no se edita.
            enabled: !_isEditing,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email],
            onChanged: (_) => _revalidateAfterChange(),
            onSubmitted: (_) => _focusNextField(),
          ),
          const SizedBox(height: AppSpacing.s4),
          AppPhoneField(
            countryCodes: widget.controller.countryCodes,
            selectedCountryCode: widget.controller.selectedCountryCode,
            onCountryCodeSelected: _selectCountryCode,
            phoneController: _phoneController,
            loading: widget.controller.isLoadingCountryCodes,
            errorMessage: widget.controller.countryCodesError,
            phoneErrorText: _phoneError,
            onRetry: () => _loadCatalogs(forceRefresh: true),
            label: 'Teléfono',
            hint: '300 123 4567',
            textInputAction: _isEditing
                ? TextInputAction.done
                : TextInputAction.next,
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
          if (_isEditing)
            _ActiveStateField(
              isActive: widget.initialData?.isActive ?? true,
              onChanged: null,
            )
          else
            _InitialStatusField(
              pendingApproval: _pendingApproval,
              onChanged: _selectInitialStatus,
            ),
        ],
      ),
    ];
  }
}

/// Aviso de qué se puede modificar en edición.
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
              'Puedes actualizar los datos legales y de contacto. El correo '
              'identifica la cuenta de acceso y no se edita; el estado se '
              'cambia desde la lista de propietarios.',
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

/// Estado con el que nace la cuenta de acceso del propietario.
class _InitialStatusField extends StatelessWidget {
  const _InitialStatusField({
    required this.pendingApproval,
    required this.onChanged,
  });

  final bool pendingApproval;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Estado inicial de la cuenta', style: textTheme.bodyLarge),
          const SizedBox(height: AppSpacing.s3),
          Wrap(
            spacing: AppSpacing.s2,
            children: [
              ChoiceChip(
                label: const Text('Activo'),
                selected: !pendingApproval,
                onSelected: (_) => onChanged(false),
              ),
              ChoiceChip(
                label: const Text('Pendiente de aprobación'),
                selected: pendingApproval,
                onSelected: (_) => onChanged(true),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s2),
          Text(
            pendingApproval
                ? 'La cuenta podrá iniciar sesión cuando otro administrador '
                      'la apruebe.'
                : 'El propietario puede administrar sus moteles de inmediato, '
                      'tras cambiar la contraseña temporal.',
            style: textTheme.bodySmall?.copyWith(
              color: context.appColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Confirmación con el resumen de la información que quedó registrada.
class _OwnerCreatedSummary extends StatelessWidget {
  const _OwnerCreatedSummary({required this.owner, this.temporaryPassword});

  final Owner owner;

  /// Contraseña temporal de la cuenta; se muestra una sola vez.
  final String? temporaryPassword;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final password = temporaryPassword;
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
        if (password != null) ...[
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Contraseña temporal', style: textTheme.bodyLarge),
                const SizedBox(height: AppSpacing.s2),
                SelectableText(password, style: textTheme.headlineSmall),
                const SizedBox(height: AppSpacing.s2),
                Text(
                  'Se muestra una sola vez. Entrégasela al propietario para su '
                  'primer inicio de sesión; la app le pedirá cambiarla.',
                  style: textTheme.bodySmall?.copyWith(
                    color: context.appColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.s6),
        ],
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
    required this.documentTypes,
    required this.onSelected,
  });

  final DocumentType selectedType;

  /// Tipos activos del maestro (`OwnerController.documentTypes`).
  final List<DocumentType> documentTypes;

  /// `null` deja el selector en solo lectura.
  final ValueChanged<DocumentType>? onSelected;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final onSelected = this.onSelected;
    // En solo lectura solo se conserva el tipo seleccionado: las demás opciones
    // no aportan nada si no se pueden elegir.
    final types = onSelected == null ? [selectedType] : documentTypes;
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
            for (final documentType in types)
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
    required this.isSaving,
    required this.onSubmit,
    required this.onCancel,
  });

  final OwnerFormMode mode;
  final bool isSaving;
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
            onPressed: isSaving ? null : onCancel,
          ),
        ),
        const SizedBox(width: AppSpacing.s3),
        Expanded(
          flex: 2,
          child: AppButton(
            label: mode == OwnerFormMode.create
                ? 'Crear propietario'
                : 'Guardar cambios',
            loading: isSaving,
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

/// Teclado adecuado para capturar cada tipo de documento.
///
/// Vive en la vista porque `DocumentType` describe el dominio y no debe
/// depender de Flutter.
extension on DocumentType {
  TextInputType get keyboardType => switch (this) {
    DocumentType.passport => TextInputType.text,
    _ => TextInputType.number,
  };
}
