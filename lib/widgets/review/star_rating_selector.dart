import 'package:flutter/material.dart';
import '../../core/design_system/design_system.dart';

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