import 'package:flutter/material.dart';
import 'package:machuco/models/review/review.dart';
import 'package:machuco/models/room/room_models.dart';
import '../../core/design_system/design_system.dart';
import 'star_rating_selector.dart';

/// Formulario para escribir una reseña.
///
/// No construye la [Review]: arma un [ReviewDraft] y lo entrega a [onSave],
/// que es el controlador quien decide si es válida y la persiste.
class AddReviewSheet extends StatefulWidget {
  final String motelId;
  final String motelName;

  /// Recibe el borrador y devuelve `true` si la reseña se guardó; solo en ese
  /// caso el formulario se cierra.
  final Future<bool> Function(ReviewDraft draft) onSave;
  final List<RoomVisualData>? rooms;

  /// Recupera el borrador guardado, si lo hay, al abrir el formulario.
  final Future<ReviewDraft?> Function()? loadDraft;

  /// Se invoca cada vez que cambia algún campo, para persistir el borrador.
  final void Function(ReviewDraft draft)? onDraftChanged;

  const AddReviewSheet({
    super.key,
    required this.onSave,
    required this.motelId,
    required this.motelName,
    required this.rooms,
    this.loadDraft,
    this.onDraftChanged,
  });

  static Future<void> show(
    BuildContext context, {
    required String motelId,
    required String motelName,
    required Future<bool> Function(ReviewDraft draft) onSave,
    required List<RoomVisualData>? rooms,
    Future<ReviewDraft?> Function()? loadDraft,
    void Function(ReviewDraft draft)? onDraftChanged,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => AddReviewSheet(
        onSave: onSave,
        motelId: motelId,
        motelName: motelName,
        rooms: rooms,
        loadDraft: loadDraft,
        onDraftChanged: onDraftChanged,
      ),
    );
  }

  @override
  State<AddReviewSheet> createState() => _AddReviewSheetState();
}

class _AddReviewSheetState extends State<AddReviewSheet> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();

  String? _selectedRoomId;
  ReviewType _reviewType = ReviewType.motel;
  int _rating = 0;
  bool _submitted = false;
  bool _draftRestored = false;

  @override
  void initState() {
    super.initState();
    _restoreDraft();
  }

  Future<void> _restoreDraft() async {
    final draft = await widget.loadDraft?.call();
    if (draft == null || !mounted) return;

    // Si la persona ya empezó a escribir, no se pisa lo que lleva.
    final untouched =
        _rating == 0 &&
        _titleController.text.isEmpty &&
        _bodyController.text.isEmpty;
    if (!untouched) return;

    setState(() {
      _reviewType = draft.type;
      // La habitación del borrador pudo dejar de existir en el motel.
      final roomExists = (widget.rooms ?? []).any(
        (room) => room.id == draft.roomId,
      );
      if (roomExists) _selectedRoomId = draft.roomId;
      _rating = draft.rating;
      _titleController.text = draft.title;
      _bodyController.text = draft.body;
      _draftRestored = true;
    });
  }

  void _notifyDraftChanged() {
    widget.onDraftChanged?.call((
      type: _reviewType,
      roomId: _selectedRoomId,
      rating: _rating,
      title: _titleController.text,
      body: _bodyController.text,
    ));
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _submitted = true);
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();
    if (!ReviewRules.isValidRating(_rating) ||
        !ReviewRules.isValidText(title) ||
        !ReviewRules.isValidText(body)) {
      return;
    }

    final saved = await widget.onSave((
      type: _reviewType,
      roomId: _selectedRoomId,
      rating: _rating,
      title: title,
      body: body,
    ));

    if (!saved || !mounted) return;
    Navigator.of(context).pop();
  }

  String? get _ratingError => _submitted && !ReviewRules.isValidRating(_rating)
      ? 'Selecciona una calificación'
      : null;
  String? get _titleError =>
      _submitted && !ReviewRules.isValidText(_titleController.text)
      ? 'Campo requerido'
      : null;
  String? get _bodyError =>
      _submitted && !ReviewRules.isValidText(_bodyController.text)
      ? 'Campo requerido'
      : null;

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

              // Selector de tipo de reseña
              DropdownButtonFormField<ReviewType>(
                // Al restaurar el borrador se recrea para tomar el tipo guardado.
                key: ValueKey('reviewType-$_draftRestored'),
                initialValue: _reviewType,
                decoration: const InputDecoration(
                  labelText: '¿Qué deseas reseñar?',
                  prefixIcon: Icon(Icons.sell_outlined),
                ),
                items: ReviewType.values.map((type) {
                  return DropdownMenuItem<ReviewType>(
                    value: type,
                    child: Text(type.label),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _reviewType = value);
                    _notifyDraftChanged();
                  }
                },
              ),
              const SizedBox(height: AppSpacing.s4),

              // Selector de habitación (solo visible si se reseña la habitación)
              if (_reviewType == ReviewType.room &&
                  (widget.rooms ?? []).isNotEmpty) ...[
                DropdownButtonFormField<String>(
                  initialValue: _selectedRoomId,
                  decoration: const InputDecoration(
                    labelText: 'Seleccionar habitación',
                    prefixIcon: Icon(Icons.kitchen_outlined),
                  ),
                  items: (widget.rooms ?? [])
                      .map(
                        (room) => DropdownMenuItem<String>(
                          value: room.id,
                          child: Text(
                            room.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedRoomId = value);
                      _notifyDraftChanged();
                    }
                  },
                ),
                const SizedBox(height: AppSpacing.s4),
              ],

              StarRatingSelector(
                // Al restaurar el borrador se recrea para tomar la calificación guardada.
                key: ValueKey('rating-$_draftRestored'),
                initialRating: _rating,
                onChanged: (v) {
                  setState(() => _rating = v);
                  _notifyDraftChanged();
                },
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
                  _notifyDraftChanged();
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
                  _notifyDraftChanged();
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
