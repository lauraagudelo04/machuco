import 'package:flutter/material.dart';
import '../../controllers/notification/notification_controller.dart';
import '../../core/design_system/components/app_button.dart';
import '../../core/design_system/components/app_text_field.dart';
import '../../core/design_system/theme/app_theme_extensions.dart';
import '../../core/design_system/tokens/app_colors.dart';
import '../../core/design_system/tokens/app_radius.dart';
import '../../core/design_system/tokens/app_spacing.dart';
import '../../models/notification/notification_model.dart';

class CreateNotificationSheet extends StatefulWidget {
  const CreateNotificationSheet({super.key});

  @override
  State<CreateNotificationSheet> createState() =>
      _CreateNotificationSheetState();
}

class _CreateNotificationSheetState extends State<CreateNotificationSheet> {
  final NotificationController _controller = NotificationController();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _recipientController = TextEditingController();

  NotificationType _selectedType = NotificationType.system;
  NotificationTarget _selectedTarget = NotificationTarget.all;

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    _recipientController.dispose();
    super.dispose();
  }

  void _sendNotification() {
    final title = _titleController.text.trim();
    final message = _messageController.text.trim();
    final recipient = _recipientController.text.trim();

    if (title.isEmpty || message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor completa el título y el mensaje.'),
          backgroundColor: AppColors.rose,
        ),
      );
      return;
    }

    if (_selectedTarget == NotificationTarget.specificUser && recipient.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ingresa el correo o ID del usuario destino.'),
          backgroundColor: AppColors.rose,
        ),
      );
      return;
    }

    _controller.addNotification(
      type: _selectedType,
      title: title,
      message: message,
      target: _selectedTarget,
      recipientUser: _selectedTarget == NotificationTarget.specificUser
          ? recipient
          : null,
    );

    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _selectedTarget == NotificationTarget.all
              ? 'Notificación enviada a TODOS los usuarios.'
              : 'Notificación enviada a: $recipient',
        ),
        backgroundColor: AppColors.available,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s4),

            // Target selector: All vs Specific
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
                        setState(() => _selectedTarget = NotificationTarget.all);
                      }
                    },
                  ),
                ),
                const SizedBox(width: AppSpacing.s2),
                Expanded(
                  child: ChoiceChip(
                    label: const Center(child: Text('Usuario específico')),
                    selected: _selectedTarget == NotificationTarget.specificUser,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() =>
                            _selectedTarget = NotificationTarget.specificUser);
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

            // Notification Type selector
            Text(
              'Tipo de Notificación',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: AppSpacing.s2),
            Wrap(
              spacing: AppSpacing.s2,
              children: NotificationType.values.map((type) {
                return ChoiceChip(
                  avatar: Icon(type.icon, size: 16, color: type.color),
                  label: Text(type.label),
                  selected: _selectedType == type,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _selectedType = type);
                    }
                  },
                );
              }).toList(),
            ),

            const SizedBox(height: AppSpacing.s4),

            // Title
            AppTextField(
              label: 'Título de la Notificación',
              hint: 'ej: Mantenimiento del sistema',
              controller: _titleController,
              prefixIcon: const Icon(Icons.title),
            ),

            const SizedBox(height: AppSpacing.s3),

            // Message / Body
            AppTextField(
              label: 'Contenido / Mensaje',
              hint: 'Escribe el mensaje completo de la notificación...',
              controller: _messageController,
              maxLines: 3,
              prefixIcon: const Icon(Icons.message_outlined),
            ),

            const SizedBox(height: AppSpacing.s5),

            // Action Button
            AppButton(
              label: 'Enviar Notificación',
              icon: Icons.send,
              onPressed: _sendNotification,
            ),
          ],
        ),
      ),
    );
  }
}
