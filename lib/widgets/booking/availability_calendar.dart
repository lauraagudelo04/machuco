import 'package:flutter/material.dart';

import 'package:machuco/core/design_system/theme/app_theme_extensions.dart';
import 'package:machuco/core/design_system/tokens/app_colors.dart';
import 'package:machuco/core/design_system/tokens/app_spacing.dart';

const List<String> _weekdayInitials = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
const List<String> _monthNames = [
  'enero',
  'febrero',
  'marzo',
  'abril',
  'mayo',
  'junio',
  'julio',
  'agosto',
  'septiembre',
  'octubre',
  'noviembre',
  'diciembre',
];

/// Calendario mensual que resalta únicamente los días con disponibilidad
/// (según [isDayAvailable]) y permite seleccionar uno. No depende de
/// ningún controlador concreto: la disponibilidad se calcula afuera y se
/// entrega por callback, para que el widget sea reutilizable desde
/// cualquier flujo de reserva.
class AvailabilityCalendar extends StatefulWidget {
  const AvailabilityCalendar({
    super.key,
    required this.selectedDay,
    required this.onDaySelected,
    required this.isDayAvailable,
  });

  final DateTime? selectedDay;
  final ValueChanged<DateTime> onDaySelected;
  final bool Function(DateTime day) isDayAvailable;

  @override
  State<AvailabilityCalendar> createState() => _AvailabilityCalendarState();
}

class _AvailabilityCalendarState extends State<AvailabilityCalendar> {
  late DateTime _visibleMonth;

  @override
  void initState() {
    super.initState();
    final base = widget.selectedDay ?? DateTime.now();
    _visibleMonth = DateTime(base.year, base.month);
  }

  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  void _changeMonth(int delta) {
    setState(
      () => _visibleMonth = DateTime(
        _visibleMonth.year,
        _visibleMonth.month + delta,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final firstWeekday = DateTime(
      _visibleMonth.year,
      _visibleMonth.month,
      1,
    ).weekday;
    final daysInMonth = DateTime(
      _visibleMonth.year,
      _visibleMonth.month + 1,
      0,
    ).day;
    final leadingBlanks = firstWeekday - 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              tooltip: 'Mes anterior',
              onPressed: () => _changeMonth(-1),
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: Text(
                '${_monthNames[_visibleMonth.month - 1]} ${_visibleMonth.year}',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            IconButton(
              tooltip: 'Mes siguiente',
              onPressed: () => _changeMonth(1),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s1),
        Row(
          children: [
            for (final initial in _weekdayInitials)
              Expanded(
                child: Center(
                  child: Text(
                    initial,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: context.appColors.textMuted,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.s1),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
          ),
          itemCount: leadingBlanks + daysInMonth,
          itemBuilder: (context, index) {
            if (index < leadingBlanks) return const SizedBox.shrink();
            final day = index - leadingBlanks + 1;
            final date = DateTime(_visibleMonth.year, _visibleMonth.month, day);
            return _DayCell(
              date: date,
              today: _today,
              selected: widget.selectedDay,
              available: widget.isDayAvailable(date),
              onTap: widget.onDaySelected,
            );
          },
        ),
        const SizedBox(height: AppSpacing.s2),
        Row(
          children: [
            _LegendDot(color: AppColors.available),
            const SizedBox(width: AppSpacing.s1),
            Text(
              'Con disponibilidad',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: context.appColors.textSecondary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color});
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    width: 8,
    height: 8,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.date,
    required this.today,
    required this.selected,
    required this.available,
    required this.onTap,
  });

  final DateTime date;
  final DateTime today;
  final DateTime? selected;
  final bool available;
  final ValueChanged<DateTime> onTap;

  bool get _isPast => date.isBefore(today);
  bool get _isSelected =>
      selected != null &&
      selected!.year == date.year &&
      selected!.month == date.month &&
      selected!.day == date.day;

  @override
  Widget build(BuildContext context) {
    final enabled = !_isPast && available;
    final background = _isSelected
        ? AppColors.violet
        : enabled
        ? AppColors.available.withValues(alpha: .16)
        : Colors.transparent;
    final foreground = _isSelected
        ? Colors.white
        : enabled
        ? Theme.of(context).colorScheme.onSurface
        : context.appColors.textDisabled;

    return Padding(
      padding: const EdgeInsets.all(2),
      child: Semantics(
        button: enabled,
        selected: _isSelected,
        label: enabled
            ? 'Día ${date.day}, con disponibilidad'
            : 'Día ${date.day}, sin disponibilidad',
        child: Material(
          color: background,
          shape: const CircleBorder(),
          child: InkWell(
            onTap: enabled ? () => onTap(date) : null,
            customBorder: const CircleBorder(),
            child: Center(
              child: FittedBox(
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${date.day}',
                        style: TextStyle(
                          color: foreground,
                          fontWeight: _isSelected
                              ? FontWeight.w700
                              : FontWeight.w400,
                        ),
                      ),
                      if (enabled && !_isSelected)
                        Container(
                          width: 4,
                          height: 4,
                          margin: const EdgeInsets.only(top: 2),
                          decoration: const BoxDecoration(
                            color: AppColors.available,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
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
