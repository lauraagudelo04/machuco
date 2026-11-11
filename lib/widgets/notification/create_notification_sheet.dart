import 'package:flutter/material.dart';
import 'package:machuco/controllers/notification/notification_controller.dart';
import 'package:machuco/core/design_system/components/app_button.dart';
import 'package:machuco/core/design_system/components/app_text_field.dart';
import 'package:machuco/core/design_system/theme/app_theme_extensions.dart';
import 'package:machuco/core/design_system/tokens/app_colors.dart';
import 'package:machuco/core/design_system/tokens/app_radius.dart';
import 'package:machuco/core/design_system/tokens/app_spacing.dart';
import 'package:machuco/models/notification/notification_model.dart';

class CreateNotificationSheet extends StatefulWidget {
  const CreateNotificationSheet({super.key, required this.controller});

  final NotificationController controller;

  @override
  State<CreateNotificationSheet> createState() =>
      _CreateNotificationSheetState();
}

class _CreateNotificationSheetState extends State<CreateNotificationSheet> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _recipientController = TextEditingController();

  NotificationType? _selectedType;
  NotificationTarget _selectedTarget = NotificationTarget.all;
  NotificationRecipient? _selectedRecipient;
  List<NotificationRecipient> _recipientResults = const [];
  bool _isSearchingRecipients = false;
  final String _deliveryId =
      'manual-${DateTime.now().microsecondsSinceEpoch}-${identityHashCode(Object())}';

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    _recipientController.dispose();
    super.dispose();
  }

  Future<void> _sendNotification() async {
    final type = _selectedType;
    final title = _titleController.text.trim();
    final message = _messageController.text.trim();
    final recipient = _selectedRecipient;

    if (type == null) {
      _showError('No hay tipos de notificación disponibles.');
      return;
    }
    if (title.isEmpty || message.isEmpty) {
      _showError('Por favor completa el título y el mensaje.');
      return;
    }
    if (_selectedTarget == NotificationTarget.specificUser &&
        recipient == null) {
      _showError('Busca y selecciona un usuario destino.');
      return;
    }

    try {
      await widget.controller.addNotification(
        type: type,
        title: title,
        message: message,
        target: _selectedTarget,
        recipientUid: _selectedTarget == NotificationTarget.specificUser
            ? recipient?.uid
            : null,
        recipientName: _selectedTarget == NotificationTarget.specificUser
            ? recipient?.fullName
            : null,
        recipientEmail: _selectedTarget == NotificationTarget.specificUser
            ? recipient?.email
            : null,
        remoteId: _deliveryId,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _selectedTarget == NotificationTarget.specificUser
                ? 'Notificación guardada para: ${recipient!.label}'
                : 'Notificación guardada para ${_selectedTarget.label.toLowerCase()}.',
          ),
          backgroundColor: AppColors.available,
        ),
      );
    } on NotificationDeliveryException catch (error) {
      _showError(error.message);
    } on ArgumentError catch (error) {
      _showError(error.message?.toString() ?? 'Datos inválidos.');
    } catch (_) {
      _showError('No se pudo guardar la notificación.');
    }
  }

  Future<void> _searchRecipients(String value) async {
    setState(() => _isSearchingRecipients = true);
    try {
      final results = await widget.controller.searchRecipients(value);
      if (mounted && _recipientController.text.trim() == value.trim()) {
        setState(() => _recipientResults = results);
      }
    } catch (_) {
      if (mounted) setState(() => _recipientResults = const []);
    } finally {
      if (mounted) setState(() => _isSearchingRecipients = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.rose),
    );
  }

  @override
  Widget build(BuildContext context) {
    final types = widget.controller.types;
    _selectedType ??= types.isEmpty ? null : types.first;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.screen,
        AppSpacing.s4,
        AppSpacing.screen,
        AppSpacing.screen + bottomInset,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.xl),
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: context.appColors.borderStrong,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.s4),
            Row(
              children: [
                const Icon(Icons.notifications_active, color: AppColors.violet),
                const SizedBox(width: AppSpacing.s2),
                Text(
                  'Crear Notificación (Admin)',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s4),
            Text(
              '¿A quién va dirigida?',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: AppSpacing.s2),
            Wrap(
              spacing: AppSpacing.s2,
              runSpacing: AppSpacing.s2,
              children: NotificationTarget.values
                  .map(
                    (target) => ChoiceChip(
                      label: Text(target.label),
                      selected: _selectedTarget == target,
                      onSelected: (selected) {
                        if (selected) setState(() => _selectedTarget = target);
                      },
                    ),
                  )
                  .toList(growable: false),
            ),
            if (_selectedTarget == NotificationTarget.specificUser) ...[
              const SizedBox(height: AppSpacing.s3),
              AppTextField(
                label: 'Buscar usuario por correo',
                hint: 'Escribe al menos 2 caracteres',
                controller: _recipientController,
                prefixIcon: const Icon(Icons.person_outline),
                onChanged: _searchRecipients,
              ),
              if (_isSearchingRecipients)
                const Padding(
                  padding: EdgeInsets.only(top: AppSpacing.s2),
                  child: LinearProgressIndicator(),
                ),
              if (_selectedRecipient != null)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.s2),
                  child: Text(
                    'Seleccionado: ${_selectedRecipient!.label}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              if (_recipientResults.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: AppSpacing.s2),
                  decoration: BoxDecoration(
                    border: Border.all(color: context.appColors.borderStrong),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Column(
                    children: _recipientResults
                        .map(
                          (candidate) => Material(
                            type: MaterialType.transparency,
                            child: ListTile(
                              dense: true,
                              title: Text(
                                candidate.fullName.isEmpty
                                    ? candidate.email
                                    : candidate.fullName,
                              ),
                              subtitle: Text(
                                '${candidate.email} · ${candidate.role == 'client' ? 'Cliente' : 'Propietario'}',
                              ),
                              onTap: () => setState(() {
                                _selectedRecipient = candidate;
                                _recipientController.text = candidate.email;
                                _recipientResults = const [];
                              }),
                            ),
                          ),
                        )
                        .toList(growable: false),
                  ),
                ),
            ],
            const SizedBox(height: AppSpacing.s4),
            Text(
              'Tipo de Notificación',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: AppSpacing.s2),
            if (types.isEmpty)
              Text(
                widget.controller.errorMessage ??
                    'No hay tipos de notificación disponibles.',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.rose),
              )
            else
              Wrap(
                spacing: AppSpacing.s2,
                children: types
                    .map((type) {
                      return ChoiceChip(
                        avatar: Icon(type.icon, size: 16, color: type.color),
                        label: Text(type.name),
                        selected: _selectedType?.id == type.id,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() => _selectedType = type);
                          }
                        },
                      );
                    })
                    .toList(growable: false),
              ),
            const SizedBox(height: AppSpacing.s4),
            AppTextField(
              label: 'Título de la Notificación',
              hint: 'ej: Mantenimiento del sistema',
              controller: _titleController,
              prefixIcon: const Icon(Icons.title),
            ),
            const SizedBox(height: AppSpacing.s3),
            AppTextField(
              label: 'Contenido / Mensaje',
              hint: 'Escribe el mensaje completo de la notificación...',
              controller: _messageController,
              maxLines: 3,
              prefixIcon: const Icon(Icons.message_outlined),
            ),
            const SizedBox(height: AppSpacing.s5),
            AppButton(
              label: 'Enviar Notificación',
              icon: Icons.send,
              onPressed: widget.controller.isSaving ? null : _sendNotification,
            ),
          ],
        ),
      ),
    );
  }
}
