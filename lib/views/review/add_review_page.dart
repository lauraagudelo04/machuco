import 'package:flutter/material.dart';
import '../../core/design_system/design_system.dart';

// Model
class Review {
  final String author;
  final String title;
  final String body;
  final int rating;
  final DateTime date;

  const Review({
    required this.author,
    required this.title,
    required this.body,
    required this.rating,
    required this.date,
  });
}

// Star rating selector
class StarRatingSelector extends StatefulWidget {
  final int initialRating;
  final ValueChanged<int> onChanged;

  const StarRatingSelector({
    super.key,
    this.initialRating = 0,
    required this.onChanged,
  });

  @override
  State<StarRatingSelector> createState() => _StarRatingSelectorState();
}

class _StarRatingSelectorState extends State<StarRatingSelector> {
  late int _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialRating;
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Calificación: $_selected de 5 estrellas',
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(5, (i) {
          final star = i + 1;
          final isSelected = star <= _selected;
          return Tooltip(
            message: '$star ${star == 1 ? "estrella" : "estrellas"}',
            child: InkWell(
              onTap: () {
                setState(() => _selected = star);
                widget.onChanged(star);
              },
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s1),
                child: AnimatedSwitcher(
                  duration: AppMotion.fast,
                  child: Icon(
                    isSelected ? Icons.star_rounded : Icons.star_outline_rounded,
                    key: ValueKey('$star-$isSelected'),
                    size: 38,
                    color: isSelected ? const Color(0xFFFFB300) : context.appColors.textMuted,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// Add review bottom sheet
class AddReviewSheet extends StatefulWidget {
  final void Function(Review review) onSave;

  const AddReviewSheet({super.key, required this.onSave});

  static Future<void> show(
    BuildContext context, {
    required void Function(Review review) onSave,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => AddReviewSheet(onSave: onSave),
    );
  }

  @override
  State<AddReviewSheet> createState() => _AddReviewSheetState();
}

class _AddReviewSheetState extends State<AddReviewSheet> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  int _rating = 0;
  bool _submitted = false;

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
        author: 'Tú',
        title: title,
        body: body,
        rating: _rating,
        date: DateTime.now(),
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

    // Ajustamos la decoración del input dentro del sheet para que contraste con la superficie
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
              
              // Stars
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
              
              // Title field
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
              
              // Body field
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
              
              // Action buttons
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

// Review card
class ReviewCard extends StatelessWidget {
  final Review review;

  const ReviewCard({super.key, required this.review});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s3),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _AuthorAvatar(initial: review.author[0]),
                const SizedBox(width: AppSpacing.s3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        review.author,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${review.date.day}/${review.date.month}/${review.date.year}',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: context.appColors.textMuted,
                            ),
                      ),
                    ],
                  ),
                ),
                _StarRow(rating: review.rating, size: 16),
              ],
            ),
            const SizedBox(height: AppSpacing.s3),
            Text(
              review.title,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: AppSpacing.s1),
            Text(
              review.body,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: context.appColors.textSecondary,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

// Star row (display-only)
class _StarRow extends StatelessWidget {
  final int rating;
  final double size;

  const _StarRow({required this.rating, this.size = 16});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        5,
        (i) => Icon(
          i < rating ? Icons.star_rounded : Icons.star_outline_rounded,
          size: size,
          color: i < rating ? const Color(0xFFFFB300) : context.appColors.textMuted,
        ),
      ),
    );
  }
}

// Author avatar
class _AuthorAvatar extends StatelessWidget {
  final String initial;

  const _AuthorAvatar({required this.initial});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        gradient: AppGradients.primary,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      alignment: Alignment.center,
      child: Text(
        initial.toUpperCase(),
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

// Reviews section
class ReviewsSection extends StatefulWidget {
  const ReviewsSection({super.key});

  @override
  State<ReviewsSection> createState() => _ReviewsSectionState();
}

class _ReviewsSectionState extends State<ReviewsSection> {
  final List<Review> _reviews = [
    Review(
      author: 'Carlos M.',
      title: 'Muy cómodo y tranquilo',
      body: 'Las habitaciones estaban limpias y el personal fue muy amable. La cama súper cómoda.',
      rating: 5,
      date: DateTime(2026, 7, 20),
    ),
    Review(
      author: 'Luisa P.',
      title: 'Buena ubicación',
      body: 'Está bien ubicado, cerca de todo. El precio es justo para lo que ofrece.',
      rating: 4,
      date: DateTime(2026, 6, 15),
    ),
    Review(
      author: 'Roberto V.',
      title: 'Aceptable',
      body: 'Correcto para una noche. El wifi un poco lento pero el resto bien.',
      rating: 3,
      date: DateTime(2026, 5, 3),
    ),
  ];

  double get _average =>
      _reviews.isEmpty
          ? 0
          : _reviews.map((r) => r.rating).reduce((a, b) => a + b) / _reviews.length;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        Row(
          children: [
            Text(
              'Reseñas',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(width: AppSpacing.s2),
            const Icon(Icons.star_rounded, color: Color(0xFFFFB300), size: 20),
            const SizedBox(width: AppSpacing.s1),
            Text(
              _average.toStringAsFixed(1),
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            Text(
              ' (${_reviews.length})',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: context.appColors.textMuted,
                  ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s4),
        
        // Review cards
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _reviews.length,
          itemBuilder: (_, i) => ReviewCard(review: _reviews[i]),
        ),
        const SizedBox(height: AppSpacing.s2),
        
        // CTA
        AppButton(
          label: 'Añadir reseña',
          icon: Icons.rate_review_outlined,
          onPressed: () => AddReviewSheet.show(
            context,
            onSave: (review) => setState(() => _reviews.insert(0, review)),
          ),
        ),
      ],
    );
  }
}