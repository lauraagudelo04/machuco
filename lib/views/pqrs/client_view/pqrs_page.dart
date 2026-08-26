import 'package:flutter/material.dart';

import '../../../core/design_system/components/app_button.dart';
import '../../../core/design_system/components/app_card.dart';
import '../../../core/design_system/components/app_feedback.dart';
import '../../../core/design_system/components/app_text_field.dart';
import '../../../core/design_system/theme/app_theme_extensions.dart';
import '../../../core/design_system/tokens/app_spacing.dart';
import '../data/pqrs_mock_data.dart';
import '../data/pqrs_store.dart';
import '../models/pqrs_models.dart';
import '../widgets/pqrs_photo.dart';
import '../widgets/pqrs_request_card.dart';
import 'pqrs_detail_page.dart';

/// PQRS view of the client: files requests, attaches photos of what was found,
/// follows the answers and is the only profile allowed to close a request.
class ClientPqrsPage extends StatefulWidget {
  const ClientPqrsPage({super.key, this.store});

  /// Injectable for tests; defaults to the shared instance.
  final PqrsStore? store;

  @override
  State<ClientPqrsPage> createState() => _ClientPqrsPageState();
}

class _ClientPqrsPageState extends State<ClientPqrsPage> {
  final _subjectController = TextEditingController();
  final _descriptionController = TextEditingController();
  final List<PqrsAttachment> _attachments = [];

  PqrsType? _selectedType;
  bool _validationAttempted = false;
  bool _sending = false;

  PqrsStore get _store => widget.store ?? PqrsStore.instance;

  @override
  void dispose() {
    _subjectController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  String? get _typeError => _validationAttempted && _selectedType == null
      ? 'Selecciona un tipo de solicitud'
      : null;

  String? get _subjectError =>
      _validationAttempted && _subjectController.text.trim().isEmpty
          ? 'Campo requerido'
          : null;

  String? get _descriptionError =>
      _validationAttempted && _descriptionController.text.trim().isEmpty
          ? 'Campo requerido'
          : null;

  bool get _isValid =>
      _selectedType != null &&
      _subjectController.text.trim().isNotEmpty &&
      _descriptionController.text.trim().isNotEmpty;

  void _attachPhoto() {
    setState(() {
      _attachments.add(
        PqrsAttachment.simulated(
          author: PqrsActor.client,
          label: 'hallazgo-${_attachments.length + 1}.jpg',
        ),
      );
    });
  }

  Future<void> _submit() async {
    setState(() => _validationAttempted = true);
    if (!_isValid) return;

    setState(() => _sending = true);
    // Simulated latency: there is no network layer in the project yet.
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;

    _store.createRequest(
      motelId: pqrsDemoOwnerMotelId,
      motelName: 'Motel Aurora',
      clientId: pqrsDemoClientId,
      clientName: 'Ana Pérez',
      type: _selectedType!,
      subject: _subjectController.text.trim(),
      description: _descriptionController.text.trim(),
      attachments: List.of(_attachments),
    );

    setState(() {
      _sending = false;
      _validationAttempted = false;
      _selectedType = null;
      _attachments.clear();
      _subjectController.clear();
      _descriptionController.clear();
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Tu solicitud fue radicada correctamente.')),
    );
  }

  void _openDetail(PqrsRequest request) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ClientPqrsDetailPage(requestId: request.id, store: _store),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Mis PQRS')),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _store,
          builder: (context, _) {
            final requests = _store.byClient(pqrsDemoClientId);
            final awaitingClosure =
                requests.where((request) => request.canBeClosedByClient).length;

            return ListView(
              padding: const EdgeInsets.all(AppSpacing.screen),
              children: [
                Text(
                  'Peticiones, quejas, reclamos y sugerencias',
                  style: theme.textTheme.headlineMedium,
                ),
                const SizedBox(height: AppSpacing.s2),
                Text(
                  'Cuéntanos qué pasó y adjunta fotos de lo que encontraste. '
                  'Cuando la solución te convenza, tú cierras la solicitud.',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: context.appColors.textSecondary),
                ),
                if (awaitingClosure > 0) ...[
                  const SizedBox(height: AppSpacing.s4),
                  _AwaitingClosureBanner(count: awaitingClosure),
                ],
                const SizedBox(height: AppSpacing.s5),
                _buildForm(context),
                const SizedBox(height: AppSpacing.s6),
                Text('Mis solicitudes', style: theme.textTheme.headlineSmall),
                const SizedBox(height: AppSpacing.s3),
                if (requests.isEmpty)
                  const AppEmptyState(
                    icon: Icons.inbox_outlined,
                    title: 'Sin solicitudes',
                    message: 'Aún no has radicado ninguna PQRS.',
                  )
                else
                  ...requests.map(
                    (request) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.s3),
                      child: PqrsRequestCard(
                        request: request,
                        showMotel: true,
                        onTap: () => _openDetail(request),
                        trailingHint:
                            request.canBeClosedByClient ? 'Requiere tu cierre' : null,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Nueva solicitud', style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.s4),
          Text('Tipo de solicitud', style: theme.textTheme.labelLarge),
          const SizedBox(height: AppSpacing.s2),
          Wrap(
            spacing: AppSpacing.s2,
            runSpacing: AppSpacing.s2,
            children: PqrsType.values.map((type) {
              return ChoiceChip(
                avatar: Icon(type.icon, size: 18),
                label: Text(type.label),
                selected: _selectedType == type,
                onSelected: (_) => setState(() => _selectedType = type),
              );
            }).toList(),
          ),
          if (_typeError != null) ...[
            const SizedBox(height: AppSpacing.s2),
            Text(
              _typeError!,
              style: theme.textTheme.labelMedium
                  ?.copyWith(color: theme.colorScheme.error),
            ),
          ],
          const SizedBox(height: AppSpacing.s4),
          AppTextField(
            label: 'Asunto',
            controller: _subjectController,
            hint: 'Ej. Demora en el check-in',
            errorText: _subjectError,
            onChanged: (_) {
              if (_validationAttempted) setState(() {});
            },
          ),
          const SizedBox(height: AppSpacing.s4),
          AppTextField(
            label: 'Descripción',
            controller: _descriptionController,
            hint: 'Describe con detalle lo que encontraste...',
            errorText: _descriptionError,
            maxLines: 5,
            onChanged: (_) {
              if (_validationAttempted) setState(() {});
            },
          ),
          if (_attachments.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.s4),
            PqrsPhotoStrip(
              attachments: _attachments,
              onRemove: (attachment) =>
                  setState(() => _attachments.remove(attachment)),
            ),
          ],
          const SizedBox(height: AppSpacing.s4),
          AppButton(
            label: 'Adjuntar foto del hallazgo',
            icon: Icons.add_a_photo_outlined,
            variant: AppButtonVariant.secondary,
            onPressed: _attachPhoto,
          ),
          const SizedBox(height: AppSpacing.s3),
          AppButton(
            label: 'Radicar solicitud',
            icon: Icons.send_outlined,
            loading: _sending,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}

class _AwaitingClosureBanner extends StatelessWidget {
  const _AwaitingClosureBanner({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final color = PqrsStatus.resolved.color;
    return Semantics(
      liveRegion: true,
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.s3),
        child: Row(
          children: [
            Icon(Icons.verified_outlined, color: color),
            const SizedBox(width: AppSpacing.s3),
            Expanded(
              child: Text(
                count == 1
                    ? 'Tienes 1 solicitud solucionada esperando tu cierre.'
                    : 'Tienes $count solicitudes solucionadas esperando tu cierre.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
