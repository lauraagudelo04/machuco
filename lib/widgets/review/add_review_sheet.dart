import 'package:flutter/material.dart';
import 'package:machuco/models/review/review.dart';
import 'package:machuco/models/room/room_models.dart';
import '../../core/design_system/design_system.dart';
import 'star_rating_selector.dart';

class AddReviewSheet extends StatefulWidget {
  final String parentId;
  final String name;
  final void Function(Review review) onSave;
  final List<RoomVisualData>? rooms;

  const AddReviewSheet({
    super.key,
    required this.onSave,
    required this.parentId,
    required this.rooms,
    required this.name,
  });

  static Future<void> show(
    BuildContext context, {
    required String parentId,
    required void Function(Review review) onSave,
    required List<RoomVisualData>? rooms,
    required String name,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => AddReviewSheet(
        onSave: onSave,
        parentId: parentId,
        rooms: rooms,
        name: name,
      ),
    );
  }

  @override
  State<AddReviewSheet> createState() => _AddReviewSheetState();
}

class _AddReviewSheetState extends State<AddReviewSheet> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  
  late String _selectedTag;
  int _rating = 0;
  bool _submitted = false;

  // Genera la lista de opciones: Nombre del motel + tipos de habitaciones
  List<String> get _tagOptions {
    final options = <String>[widget.name];
    if (widget.rooms != null && widget.rooms!.isNotEmpty) {
      options.addAll(widget.rooms!.map((room) => room.name));
    }
    return options;
  }

  @override
  void initState() {
    super.initState();
    _selectedTag = widget.name; // Por defecto selecciona el motel
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  void _save() {
    setState(() => _submitted = true);
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();
    if (_rating == 0 || title.isEmpty || body.isEmpty) return;

    widget.onSave(
      Review(
        parentId: widget.parentId,
        author: 'Tú',
        title: title,
        body: body,
        rating: _rating,
        date: DateTime.now(),
        tag: _selectedTag,
      ),
    );

    if (!context.mounted) return;
    Navigator.of(context).pop();
  }

  String? get _ratingError =>
      _submitted && _rating == 0 ? 'Selecciona una calificación' : null;
  String? get _titleError =>
      _submitted && _titleController.text.trim().isEmpty ? 'Campo requerido' : null;
  String? get _bodyError =>
      _submitted && _bodyController.text.trim().isEmpty ? 'Campo requerido' : null;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final theme = Theme.of(context);

    return Theme(
      data: theme.copyWith(
        inputDecorationTheme: theme.inputDecorationTheme.copyWith(
          fillColor: theme.colorScheme.surface,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: BorderSide(color: context.appColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: const BorderSide(color: AppColors.violet, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: const BorderSide(color: AppColors.rose),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: const BorderSide(color: AppColors.rose, width: 1.5),
          ),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.s5,
          AppSpacing.s1,
          AppSpacing.s5,
          AppSpacing.s6 + bottomInset,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Añadir reseña',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.s4),

              // 🔻 AQUÍ ESTÁ EL SELECCIONADOR 🔻
              DropdownButtonFormField<String>(
                value: _selectedTag,
                decoration: const InputDecoration(
                  labelText: '¿Qué deseas reseñar?',
                  prefixIcon: Icon(Icons.sell_outlined),
                ),
                items: _tagOptions.map((tag) {
                  return DropdownMenuItem<String>(
                    value: tag,
                    child: Text(
                      tag,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedTag = value);
                  }
                },
              ),
              const SizedBox(height: AppSpacing.s4),

              StarRatingSelector(
                onChanged: (v) => setState(() => _rating = v),
              ),
              if (_ratingError != null) ...[
                const SizedBox(height: AppSpacing.s2),
                Text(
                  _ratingError!,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: AppSpacing.s5),
              AppTextField(
                label: 'Título',
                controller: _titleController,
                hint: 'Ej. Excelente estadía...',
                errorText: _titleError,
                onChanged: (_) {
                  if (_submitted) setState(() {});
                },
              ),
              const SizedBox(height: AppSpacing.s4),
              AppTextField(
                label: 'Tu reseña',
                controller: _bodyController,
                hint: 'Cuéntanos tu experiencia...',
                errorText: _bodyError,
                maxLines: 4,
                onChanged: (_) {
                  if (_submitted) setState(() {});
                },
              ),
              const SizedBox(height: AppSpacing.s6),
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      label: 'Cancelar',
                      variant: AppButtonVariant.secondary,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s3),
                  Expanded(
                    child: AppButton(
                      label: 'Guardar',
                      variant: AppButtonVariant.primary,
                      onPressed: _save,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}