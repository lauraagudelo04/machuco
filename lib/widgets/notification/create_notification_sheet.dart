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
    final recipient = _recipientController.text.trim();

    if (type == null) {
      _showError('No hay tipos de notificación disponibles.');
      return;
    }
    if (title.isEmpty || message.isEmpty) {
      _showError('Por favor completa el título y el mensaje.');
      return;
    }
    if (_selectedTarget == NotificationTarget.specificUser &&
        recipient.isEmpty) {
      _showError('Ingresa el correo o ID del usuario destino.');
      return;
    }

    try {
      await widget.controller.addNotification(
        type: type,
        title: title,
        message: message,
        target: _selectedTarget,
        recipientUser: _selectedTarget == NotificationTarget.specificUser
            ? recipient
            : null,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _selectedTarget == NotificationTarget.all
                ? 'Notificación guardada para todos los usuarios.'
                : 'Notificación guardada para: $recipient',
          ),
          backgroundColor: AppColors.available,
        ),
      );
    } on ArgumentError catch (error) {
      _showError(error.message?.toString() ?? 'Datos inválidos.');
    } catch (_) {
      _showError('No se pudo guardar la notificación.');
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
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Center(child: Text('Todos los usuarios')),
                    selected: _selectedTarget == NotificationTarget.all,
                    onSelected: (selected) {
                      if (selected) {
                        setState(
                          () => _selectedTarget = NotificationTarget.all,
                        );
                      }
                    },
                  ),
                ),
                const SizedBox(width: AppSpacing.s2),
                Expanded(
                  child: ChoiceChip(
                    label: const Center(child: Text('Usuario específico')),
                    selected:
                        _selectedTarget == NotificationTarget.specificUser,
                    onSelected: (selected) {
                      if (selected) {
                        setState(
                          () =>
                              _selectedTarget = NotificationTarget.specificUser,
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
            if (_selectedTarget == NotificationTarget.specificUser) ...[
              const SizedBox(height: AppSpacing.s3),
              AppTextField(
                label: 'Usuario Destino (Correo / ID)',
                hint: 'ej: usuario@machuco.com',
                controller: _recipientController,
                prefixIcon: const Icon(Icons.person_outline),
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
