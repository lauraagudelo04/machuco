import 'package:flutter/material.dart';
import 'package:machuco/controllers/review/add_review_controller.dart';
import 'package:machuco/controllers/room/room_mock_data.dart';
import 'package:machuco/models/motel/motel_model.dart';
import 'package:machuco/models/room/room_models.dart';
import 'package:machuco/widgets/review/add_review_sheet.dart';
import 'package:machuco/widgets/review/review_card.dart';
import '../../core/design_system/design_system.dart';

/// Sección de reseñas que se puede incrustar en cualquier página.
///
/// Recibe un [ReviewsController] opcional: si no se proporciona, se crea uno
/// local que se destruye al eliminar el widget (comportamiento actual).
/// Cuando se pasa un controller desde el padre, la reseña se mantiene
/// entre navegaciones.
class ReviewsSection extends StatefulWidget {
  const ReviewsSection({
    super.key,
    required this.isComplete,
    required this.motel,
    this.controller,
    this.rooms,
  });

  final bool isComplete;
  final Motel motel;
  final ReviewsController? controller;
  final List<RoomVisualData>? rooms;

  @override
  State<ReviewsSection> createState() => _ReviewsSectionState();
}

class _ReviewsSectionState extends State<ReviewsSection> {
  late final ReviewsController _controller;
  bool _ownsController = false;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? ReviewsController();
    if (_ownsController) {
      _controller.seedReviews();
    }
  }

  @override
  void dispose() {
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final reviews = _controller.getReviewsByMotelId(widget.motel.id);
        final average = _controller.getAverageByMotelId(widget.motel.id);

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
                        motelId: widget.motel.id,
                        motelName: widget.motel.name,
                        rooms: widget.rooms ?? buildRoomMockData().where((room) => room.motelId == widget.motel.id).toList(),
                        onSave: (review) => _controller.addReview(review),
                      )
                  : null,
            ),
            const SizedBox(height: AppSpacing.s4),

            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              itemCount: reviews.length,
              itemBuilder: (_, i) => ReviewCard(review: reviews[i]),
            ),
          ],
        );
      },
    );
  }
}