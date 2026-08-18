import 'package:flutter/material.dart';

// ── Design tokens (reemplazar con AppColors/AppRadius/AppSpacing cuando el
//    design system esté configurado en core/design_system/tokens/) ──────────

abstract final class _Colors {
  static const violet = Color(0xFF8B5CF6);
  static const purple = Color(0xFFA855F7);
  static const fuchsia = Color(0xFFD946EF);
  static const rose = Color(0xFFFB7185);
  static const starAmber = Color(0xFFFFB300);

  static const darkBackground = Color(0xFF100B18);
  static const darkSurface = Color(0xFF15111F);
  static const darkElevated = Color(0xFF21182B);
  static const darkTextPrimary = Color(0xFFF8F6FF);
  static const darkTextSecondary = Color(0x8CFFFFFF);
  static const darkTextMuted = Color(0x66FFFFFF);
  static const darkBorder = Color(0x12FFFFFF);
}

abstract final class _Radius {
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 24.0;
}

abstract final class _Spacing {
  static const s1 = 4.0;
  static const s2 = 8.0;
  static const s3 = 12.0;
  static const s4 = 16.0;
  static const s5 = 20.0;
  static const s6 = 24.0;
  static const s8 = 32.0;
}

abstract final class _Motion {
  static const fast = Duration(milliseconds: 120);
}

// ── Model ─────────────────────────────────────────────────────────────────────

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

// ── Star rating selector ──────────────────────────────────────────────────────

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
            child: GestureDetector(
              onTap: () {
                setState(() => _selected = star);
                widget.onChanged(star);
              },
              child: AnimatedSwitcher(
                duration: _Motion.fast,
                child: Icon(
                  isSelected ? Icons.star_rounded : Icons.star_outline_rounded,
                  key: ValueKey('$star-$isSelected'),
                  size: 36,
                  color: isSelected ? _Colors.starAmber : _Colors.darkTextMuted,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ── Gradient primary button ───────────────────────────────────────────────────

class _GradientButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final bool isLoading;

  const _GradientButton({
    required this.onPressed,
    required this.child,
    this.isLoading = false,
  });

  @override
  State<_GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<_GradientButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _press;

  @override
  void initState() {
    super.initState();
    _press = AnimationController(
      vsync: this,
      duration: _Motion.fast,
      lowerBound: 0.97,
      upperBound: 1.0,
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null && !widget.isLoading;

    return ScaleTransition(
      scale: _press,
      child: Opacity(
        opacity: enabled ? 1.0 : 0.5,
        child: SizedBox(
          height: 52,
          child: Material(
            borderRadius: BorderRadius.circular(_Radius.lg),
            color: Colors.transparent,
            child: Ink(
              decoration: BoxDecoration(
                gradient: enabled
                    ? const LinearGradient(
                        colors: [_Colors.violet, _Colors.purple, _Colors.fuchsia],
                      )
                    : null,
                color: enabled ? null : _Colors.darkElevated,
                borderRadius: BorderRadius.circular(_Radius.lg),
                boxShadow: enabled
                    ? [
                        BoxShadow(
                          color: _Colors.violet.withValues(alpha: 0.35),
                          blurRadius: 28,
                          offset: const Offset(0, 8),
                        ),
                      ]
                    : null,
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(_Radius.lg),
                onTap: enabled ? widget.onPressed : null,
                onTapDown: (_) => _press.reverse(),
                onTapCancel: () => _press.forward(),
                onTapUp: (_) => _press.forward(),
                child: Center(
                  child: widget.isLoading
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : DefaultTextStyle(
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Inter',
                            decoration: TextDecoration.none,
                          ),
                          child: widget.child,
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Add review bottom sheet ───────────────────────────────────────────────────

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
      backgroundColor: Colors.transparent,
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

  OutlineInputBorder _border(Color color) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(_Radius.md),
        borderSide: BorderSide(color: color),
      );

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: _Spacing.s3),
      decoration: const BoxDecoration(
        color: _Colors.darkElevated,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(_Radius.xxl),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            _Spacing.s5,
            _Spacing.s4,
            _Spacing.s5,
            _Spacing.s6 + bottomInset,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _Colors.darkBorder,
                    borderRadius: BorderRadius.circular(_Radius.sm),
                  ),
                ),
              ),
              const SizedBox(height: _Spacing.s5),

              const Text(
                'Añadir reseña',
                style: TextStyle(
                  color: _Colors.darkTextPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  decoration: TextDecoration.none,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: _Spacing.s5),

              // Stars
              StarRatingSelector(
                onChanged: (v) => setState(() => _rating = v),
              ),
              if (_ratingError != null) ...[
                const SizedBox(height: _Spacing.s1),
                Text(
                  _ratingError!,
                  style: const TextStyle(
                    color: _Colors.rose,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    decoration: TextDecoration.none,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],

              const SizedBox(height: _Spacing.s5),

              // Title field
              TextField(
                controller: _titleController,
                onChanged: (_) {
                  if (_submitted) setState(() {});
                },
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(
                  fontSize: 14,
                  color: _Colors.darkTextPrimary,
                  decoration: TextDecoration.none,
                ),
                decoration: InputDecoration(
                  labelText: 'Título',
                  labelStyle: const TextStyle(color: _Colors.darkTextMuted),
                  hintText: 'Ej. Excelente estadía',
                  hintStyle: const TextStyle(color: _Colors.darkTextMuted),
                  errorText: _titleError,
                  filled: true,
                  fillColor: _Colors.darkSurface,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  border: _border(Colors.transparent),
                  enabledBorder: _border(Colors.transparent),
                  focusedBorder: _border(_Colors.violet),
                  errorBorder: _border(_Colors.rose),
                  focusedErrorBorder: _border(_Colors.rose),
                ),
              ),
              const SizedBox(height: _Spacing.s4),

              // Body field
              TextField(
                controller: _bodyController,
                onChanged: (_) {
                  if (_submitted) setState(() {});
                },
                maxLines: 5,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(
                  fontSize: 14,
                  color: _Colors.darkTextPrimary,
                  decoration: TextDecoration.none,
                ),
                decoration: InputDecoration(
                  labelText: 'Tu reseña',
                  labelStyle: const TextStyle(color: _Colors.darkTextMuted),
                  hintText: 'Cuéntanos tu experiencia…',
                  hintStyle: const TextStyle(color: _Colors.darkTextMuted),
                  alignLabelWithHint: true,
                  errorText: _bodyError,
                  filled: true,
                  fillColor: _Colors.darkSurface,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  border: _border(Colors.transparent),
                  enabledBorder: _border(Colors.transparent),
                  focusedBorder: _border(_Colors.violet),
                  errorBorder: _border(_Colors.rose),
                  focusedErrorBorder: _border(_Colors.rose),
                ),
              ),
              const SizedBox(height: _Spacing.s6),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _Colors.rose,
                          side: const BorderSide(color: _Colors.rose),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(_Radius.lg),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.none,
                          ),
                        ),
                        child: const Text('Cancelar'),
                      ),
                    ),
                  ),
                  const SizedBox(width: _Spacing.s3),
                  Expanded(
                    child: _GradientButton(
                      onPressed: _save,
                      child: const Text('Guardar'),
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

// ── Review card ───────────────────────────────────────────────────────────────

class ReviewCard extends StatelessWidget {
  final Review review;

  const ReviewCard({super.key, required this.review});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: _Spacing.s3),
      padding: const EdgeInsets.all(_Spacing.s4),
      decoration: BoxDecoration(
        color: _Colors.darkSurface,
        borderRadius: BorderRadius.circular(_Radius.lg),
        border: Border.all(color: _Colors.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _AuthorAvatar(initial: review.author[0]),
              const SizedBox(width: _Spacing.s2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.author,
                      style: const TextStyle(
                        color: _Colors.darkTextPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.none,
                      ),
                    ),
                    Text(
                      '${review.date.day}/${review.date.month}/${review.date.year}',
                      style: const TextStyle(
                        color: _Colors.darkTextMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                ),
              ),
              _StarRow(rating: review.rating, size: 15),
            ],
          ),
          const SizedBox(height: _Spacing.s3),
          Text(
            review.title,
            style: const TextStyle(
              color: _Colors.darkTextPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: _Spacing.s1),
          Text(
            review.body,
            style: const TextStyle(
              color: _Colors.darkTextSecondary,
              fontSize: 14,
              height: 1.5,
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Star row (display-only) ───────────────────────────────────────────────────

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
          color: i < rating ? _Colors.starAmber : _Colors.darkTextMuted,
        ),
      ),
    );
  }
}

// ── Author avatar ─────────────────────────────────────────────────────────────

class _AuthorAvatar extends StatelessWidget {
  final String initial;

  const _AuthorAvatar({required this.initial});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_Colors.violet, _Colors.fuchsia],
        ),
        borderRadius: BorderRadius.circular(_Radius.md),
      ),
      alignment: Alignment.center,
      child: Text(
        initial.toUpperCase(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w700,
          decoration: TextDecoration.none,
        ),
      ),
    );
  }
}

// ── Reviews section ───────────────────────────────────────────────────────────

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
            const Text(
              'Reseñas',
              style: TextStyle(
                color: _Colors.darkTextPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                decoration: TextDecoration.none,
              ),
            ),
            const SizedBox(width: _Spacing.s2),
            const Icon(Icons.star_rounded, color: _Colors.starAmber, size: 18),
            const SizedBox(width: _Spacing.s1),
            Text(
              _average.toStringAsFixed(1),
              style: const TextStyle(
                color: _Colors.darkTextPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.none,
              ),
            ),
            Text(
              ' (${_reviews.length})',
              style: const TextStyle(
                color: _Colors.darkTextMuted,
                fontSize: 14,
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ),
        const SizedBox(height: _Spacing.s4),

        // Review cards
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _reviews.length,
          itemBuilder: (_, i) => ReviewCard(review: _reviews[i]),
        ),

        const SizedBox(height: _Spacing.s2),

        // CTA
        _GradientButton(
          onPressed: () => AddReviewSheet.show(
            context,
            onSave: (review) => setState(() => _reviews.insert(0, review)),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.rate_review_outlined, size: 18, color: Colors.white),
              SizedBox(width: _Spacing.s2),
              Text('Añadir reseña'),
            ],
          ),
        ),
      ],
    );
  }
}
