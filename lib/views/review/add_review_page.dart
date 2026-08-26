import 'package:flutter/material.dart';
import '../../core/design_system/design_system.dart';
import 'package:machuco/controllers/review/add_review_controller.dart';
import 'package:machuco/widgets/review/review_card.dart';
import 'package:machuco/widgets/review/add_review_sheet.dart';

class ReviewsSection extends StatefulWidget {
  const ReviewsSection({super.key});

  @override
  State<ReviewsSection> createState() => _ReviewsSectionState();
}

class _ReviewsSectionState extends State<ReviewsSection> {
  // Instanciamos el controlador que ahora maneja la lógica
  final ReviewsController _controller = ReviewsController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Para simplificar, escuchamos los cambios usando AnimatedBuilder o ListenableBuilder
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final reviews = _controller.reviews;
        final average = _controller.average;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
                  average.toStringAsFixed(1),
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                Text(
                  ' (${reviews.length})',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: context.appColors.textMuted,
                      ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s4),
            
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: reviews.length,
              itemBuilder: (_, i) => ReviewCard(review: reviews[i]),
            ),
            const SizedBox(height: AppSpacing.s2),
            
            AppButton(
              label: 'Añadir reseña',
              icon: Icons.rate_review_outlined,
              onPressed: () => AddReviewSheet.show(
                context,
                onSave: (review) => _controller.addReview(review),
              ),
            ),
          ],
        );
      },
    );
  }
}