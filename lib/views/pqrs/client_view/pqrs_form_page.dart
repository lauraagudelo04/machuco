import 'package:flutter/material.dart';
import 'package:machuco/controllers/pqrs/pqrs_controller.dart';
import 'package:machuco/controllers/pqrs/pqrs_form_controller.dart';
import 'package:machuco/core/design_system/design_system.dart';
import 'package:machuco/models/pqrs/pqrs_type_info.dart';
import 'package:machuco/widgets/pqrs/pqrs_photo_picker_field.dart';
import 'package:machuco/widgets/pqrs/pqrs_presentation.dart';
import 'package:machuco/widgets/pqrs/pqrs_state_views.dart';

/// Form of a new request. Pops `true` when the request was filed.
class ClientPqrsFormPage extends StatefulWidget {
  const ClientPqrsFormPage({
    super.key,
    required this.controller,
    required this.form,
  });

  final PqrsController controller;
  final PqrsFormController form;

  @override
  State<ClientPqrsFormPage> createState() => _ClientPqrsFormPageState();
}

class _ClientPqrsFormPageState extends State<ClientPqrsFormPage> {
  final _subjectController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _attempted = false;

  PqrsFormController get _form => widget.form;

  @override
  void initState() {
    super.initState();
    _form.load();
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  /// Re-validates while the user fixes a field, once a send was attempted.
  void _revalidate() {
    if (!_attempted) return;
    _form.validate(
      subject: _subjectController.text,
      description: _descriptionController.text,
    );
  }

  Future<void> _submit() async {
    setState(() => _attempted = true);
    final sent = await _form.submit(
      subject: _subjectController.text,
      description: _descriptionController.text,
    );
    if (sent && mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nueva solicitud')),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: Listenable.merge([
            _form,
            _form.catalog,
            widget.controller,
          ]),
          builder: (context, _) => ListView(
            padding: const EdgeInsets.all(AppSpacing.screen),
            children: _children(context),
          ),
        ),
      ),
    );
  }

  List<Widget> _children(BuildContext context) {
    final theme = Theme.of(context);
    final errors = _form.errors;
    final sendError = _attempted ? widget.controller.error : null;

    return [
      Text(
        'Cuéntanos qué pasó y adjunta fotos de lo que encontraste.',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: context.appColors.textSecondary,
        ),
      ),
      const SizedBox(height: AppSpacing.s5),
      if (_form.catalog.notice case final notice?) ...[
        PqrsInfoBanner(message: notice, icon: Icons.cloud_off_outlined),
        const SizedBox(height: AppSpacing.s4),
      ],
      _MotelField(form: _form, errorText: errors.motel),
      const SizedBox(height: AppSpacing.s5),
      Text('Tipo de solicitud', style: theme.textTheme.labelLarge),
      const SizedBox(height: AppSpacing.s2),
      for (final info in _form.catalog.types)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.s2),
          child: _TypeOption(
            info: info,
            selected: _form.selectedType?.type == info.type,
            onTap: () => _form.selectType(info),
          ),
        ),
      if (errors.type != null) _FieldError(message: errors.type!),
      const SizedBox(height: AppSpacing.s4),
      AppTextField(
        label: 'Asunto',
        controller: _subjectController,
        hint: 'Ej. Demora en el check-in',
        errorText: errors.subject,
        onChanged: (_) => _revalidate(),
      ),
      const SizedBox(height: AppSpacing.s4),
      AppTextField(
        label: 'Descripción',
        controller: _descriptionController,
        hint: 'Describe con detalle lo que encontraste...',
        errorText: errors.description,
        maxLines: 5,
        onChanged: (_) => _revalidate(),
      ),
      if (_form.showsPhotos) ...[
        const SizedBox(height: AppSpacing.s4),
        PqrsPhotoPickerField(
          controller: _form.photos,
          label: 'Adjuntar foto del hallazgo',
        ),
      ],
      if (sendError != null) ...[
        const SizedBox(height: AppSpacing.s4),
        PqrsErrorBanner(
          message: sendError.message,
          onRetry: sendError.isRetryable ? _submit : null,
        ),
      ],
      const SizedBox(height: AppSpacing.s5),
      AppButton(
        label: 'Radicar solicitud',
        icon: Icons.send_outlined,
        loading: widget.controller.isBusy,
        onPressed: _submit,
      ),
    ];
  }
}

class _MotelField extends StatelessWidget {
  const _MotelField({required this.form, required this.errorText});

  final PqrsFormController form;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (form.isLoadingMotels && form.motels.isEmpty) {
      return const AppSkeleton(height: 56);
    }
    if (form.motelsFailed) {
      return PqrsErrorBanner(
        message: 'No pudimos cargar los moteles.',
        onRetry: form.loadMotels,
      );
    }
    if (form.motels.isEmpty) {
      return const PqrsInfoBanner(
        message: 'Aún no hay moteles disponibles para radicar una solicitud.',
        icon: Icons.apartment_outlined,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Motel', style: theme.textTheme.labelLarge),
        const SizedBox(height: AppSpacing.s2),
        DropdownButtonFormField<String>(
          initialValue: form.selectedMotel?.id,
          isExpanded: true,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.apartment_outlined),
            hintText: 'Selecciona un motel',
            errorText: errorText,
          ),
          items: [
            for (final motel in form.motels)
              DropdownMenuItem<String>(
                value: motel.id,
                child: Text(motel.name),
              ),
          ],
          onChanged: (id) {
            for (final motel in form.motels) {
              if (motel.id == id) form.selectMotel(motel);
            }
          },
        ),
      ],
    );
  }
}

class _TypeOption extends StatelessWidget {
  const _TypeOption({
    required this.info,
    required this.selected,
    required this.onTap,
  });

  final PqrsTypeInfo info;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      selected: selected,
      onTap: onTap,
      semanticLabel: '${info.name}. ${info.description}',
      padding: const EdgeInsets.all(AppSpacing.s3),
      child: Row(
        children: [
          Icon(info.type.icon, color: theme.colorScheme.primary),
          const SizedBox(width: AppSpacing.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  info.name,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  info.description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: context.appColors.textSecondary,
                  ),
                ),
                Text(
                  'Respuesta estimada: ${info.responseDays} días hábiles'
                  '${info.allowsPhotos ? '' : ' · Sin fotos'}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: context.appColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (selected)
            Icon(Icons.check_circle, color: theme.colorScheme.primary),
        ],
      ),
    );
  }
}

class _FieldError extends StatelessWidget {
  const _FieldError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      liveRegion: true,
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 16, color: theme.colorScheme.error),
          const SizedBox(width: AppSpacing.s1),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
