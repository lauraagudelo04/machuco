import 'package:flutter/material.dart';
import 'package:machuco/models/review/review_type.dart';
import '../../core/design_system/design_system.dart';
import 'package:machuco/controllers/review/add_review_controller.dart';
import 'package:machuco/widgets/review/review_card.dart';
import 'package:machuco/widgets/review/add_review_sheet.dart';

class ReviewsSection extends StatefulWidget {
  const ReviewsSection({
    super.key,
    required this.id,
    required this.reviewType,
    required this.isComplete,
  });

  final String id;
  final ReviewType reviewType;
  final bool isComplete;

  @override
  State<ReviewsSection> createState() => _ReviewsSectionState();
}

class _ReviewsSectionState extends State<ReviewsSection> {
  late final ReviewsController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ReviewsController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final reviews = _controller.getReviewsByType(widget.reviewType, widget.id);
        final average = _controller.getAverageByType(widget.reviewType, widget.id);

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
            const SizedBox(height: AppSpacing.s3),

            AppButton(
              label: 'Añadir reseña',
              icon: Icons.rate_review_outlined,
              onPressed: widget.isComplete
                  ? () => AddReviewSheet.show(
                        context,
                        reviewType: widget.reviewType,
                        onSave: (review) => _controller.addReview(review),
                        parentId: widget.id
                      )
                  : null,
            ),
            const SizedBox(height: AppSpacing.s4),

            Expanded(
                child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: reviews.length,
                itemBuilder: (_, i) => ReviewCard(review: reviews[i]),
              ),
            )
          ],
        );
      },
    );
  }
}