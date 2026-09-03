import 'package:flutter/material.dart';
import 'package:machuco/core/design_system/design_system.dart';
import 'package:machuco/models/booking/booking_checkout_data.dart';
import 'package:machuco/views/booking/booking_view_support.dart';

class BookingSection extends StatelessWidget {
  const BookingSection({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleLarge),
                    if (subtitle != null) ...[
                      const SizedBox(height: AppSpacing.s1),
                      Text(
                        subtitle!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: context.appColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: AppSpacing.s4),
          child,
        ],
      ),
    );
  }
}

class BookingStayHeader extends StatelessWidget {
  const BookingStayHeader({super.key, required this.data});

  final BookingCheckoutData data;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 460;
          final illustration = Container(
            width: compact ? double.infinity : 92,
            height: 92,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.violet, AppColors.fuchsia],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: const Icon(
              Icons.hotel_outlined,
              size: 42,
              color: Colors.white,
            ),
          );
          final details = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                data.motelName,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.s1),
              Text(
                data.motelAddress,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: context.appColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.s3),
              Wrap(
                spacing: AppSpacing.s2,
                runSpacing: AppSpacing.s2,
                children: [
                  _HeaderChip(
                    icon: Icons.bedroom_parent_outlined,
                    label: '${data.roomName} · Hab. ${data.roomNumber}',
                  ),
                  _HeaderChip(
                    icon: Icons.people_outline,
                    label: 'Máx. ${data.maxCapacity} personas',
                  ),
                ],
              ),
            ],
          );
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                illustration,
                const SizedBox(height: AppSpacing.s4),
                details,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              illustration,
              const SizedBox(width: AppSpacing.s4),
              Expanded(child: details),
            ],
          );
        },
      ),
    );
  }
}

class _HeaderChip extends StatelessWidget {
  const _HeaderChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: context.appColors.elevated,
      borderRadius: BorderRadius.circular(AppRadius.pill),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s3,
        vertical: AppSpacing.s2,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17),
          const SizedBox(width: AppSpacing.s1),
          Flexible(
            child: Text(label, style: Theme.of(context).textTheme.labelMedium),
          ),
        ],
      ),
    ),
  );
}

class BookingDateTimeTile extends StatelessWidget {
  const BookingDateTimeTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => AppCard(
    onTap: onTap,
    child: Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.violet.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Icon(icon, color: Theme.of(context).colorScheme.primary),
        ),
        const SizedBox(width: AppSpacing.s3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: context.appColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.s1),
              Text(value, style: Theme.of(context).textTheme.titleSmall),
            ],
          ),
        ),
        const Icon(Icons.edit_calendar_outlined, size: 20),
      ],
    ),
  );
}

class QuantitySelector extends StatelessWidget {
  const QuantitySelector({
    super.key,
    required this.label,
    required this.value,
    required this.minimum,
    required this.maximum,
    required this.onChanged,
    this.helperText,
  });

  final String label;
  final int value;
  final int minimum;
  final int maximum;
  final ValueChanged<int> onChanged;
  final String? helperText;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.titleMedium),
            if (helperText != null)
              Text(
                helperText!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: context.appColors.textSecondary,
                ),
              ),
          ],
        ),
      ),
      IconButton(
        onPressed: value > minimum ? () => onChanged(value - 1) : null,
        tooltip: 'Disminuir',
        icon: const Icon(Icons.remove_circle_outline),
      ),
      Semantics(
        label: '$label: $value',
        child: SizedBox(
          width: 28,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
      ),
      IconButton(
        onPressed: value < maximum ? () => onChanged(value + 1) : null,
        tooltip: 'Aumentar',
        icon: const Icon(Icons.add_circle_outline),
      ),
    ],
  );
}

class BookingOptionTile extends StatelessWidget {
  const BookingOptionTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onChanged,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final ValueChanged<bool> onChanged;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => AppCard(
    selected: selected,
    onTap: () => onChanged(!selected),
    child: Row(
      children: [
        Icon(
          icon,
          color: selected
              ? Theme.of(context).colorScheme.primary
              : context.appColors.textSecondary,
        ),
        const SizedBox(width: AppSpacing.s3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: AppSpacing.s1),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: context.appColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: AppSpacing.s2),
          trailing!,
        ],
        Checkbox(
          value: selected,
          onChanged: (value) => onChanged(value ?? false),
        ),
      ],
    ),
  );
}

class PriceBreakdownCard extends StatelessWidget {
  const PriceBreakdownCard({
    super.key,
    required this.data,
    this.title = 'Resumen de pago',
  });

  final BookingCheckoutData data;
  final String title;

  @override
  Widget build(BuildContext context) => BookingSection(
    title: title,
    child: Column(
      children: [
        PriceRow(
          label: 'Habitación (${data.billableHours} h)',
          value: formatBookingMoney(data.roomSubtotal),
        ),
        if (data.extras.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.s2),
          PriceRow(
            label: 'Adicionales y minibar',
            value: formatBookingMoney(data.extrasSubtotal),
          ),
        ],
        const SizedBox(height: AppSpacing.s2),
        PriceRow(label: 'Subtotal', value: formatBookingMoney(data.subtotal)),
        const SizedBox(height: AppSpacing.s2),
        PriceRow(label: 'IVA (19%)', value: formatBookingMoney(data.iva)),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: AppSpacing.s3),
          child: Divider(),
        ),
        PriceRow(
          label: 'Total',
          value: formatBookingMoney(data.total),
          emphasized: true,
        ),
        const SizedBox(height: AppSpacing.s3),
        Text(
          'Valores expresados en pesos colombianos. El IVA se muestra de forma discriminada.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: context.appColors.textSecondary,
          ),
        ),
      ],
    ),
  );
}

class PriceRow extends StatelessWidget {
  const PriceRow({
    super.key,
    required this.label,
    required this.value,
    this.emphasized = false,
  });
  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Text(
          label,
          style: emphasized ? Theme.of(context).textTheme.titleMedium : null,
        ),
      ),
      const SizedBox(width: AppSpacing.s3),
      Flexible(
        child: Text(
          value,
          textAlign: TextAlign.end,
          style: emphasized
              ? Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                )
              : Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    ],
  );
}

class BookingNavigationBar extends StatelessWidget {
  const BookingNavigationBar({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
  });
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => AppNavigationBar(
    selectedIndex: selectedIndex,
    onDestinationSelected: onSelected,
    destinations: const [
      AppNavigationDestination(
        icon: Icons.home_outlined,
        selectedIcon: Icons.home,
        label: 'Inicio',
      ),
      AppNavigationDestination(
        icon: Icons.event_note_outlined,
        selectedIcon: Icons.event_note,
        label: 'Mis reservas',
      ),
      AppNavigationDestination(
        icon: Icons.support_agent_outlined,
        selectedIcon: Icons.support_agent,
        label: 'Mis PQRS',
      ),
    ],
  );
}
