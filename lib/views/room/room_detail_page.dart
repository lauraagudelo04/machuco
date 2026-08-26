import 'package:flutter/material.dart';
import 'package:machuco/core/design_system/components/app_button.dart';
import 'package:machuco/core/design_system/components/app_card.dart';
import 'package:machuco/core/design_system/components/app_icon_button.dart';
import 'package:machuco/core/design_system/theme/app_theme_extensions.dart';
import 'package:machuco/core/design_system/tokens/app_radius.dart';
import 'package:machuco/core/design_system/tokens/app_spacing.dart';
import 'package:machuco/core/design_system/tokens/app_text_styles.dart';
import 'package:machuco/views/room/room_view_models.dart';

class RoomDetailPage extends StatelessWidget {
  const RoomDetailPage({
    super.key,
    required this.room,
    required this.role,
    this.selectedRangeStart,
    this.selectedRangeEnd,
    this.highlightOwnerCalendar = false,
  });

  final RoomVisualData room;
  final RoomPageRole role;
  final DateTime? selectedRangeStart;
  final DateTime? selectedRangeEnd;
  final bool highlightOwnerCalendar;

  bool get _hasClientRange => hasDateRange(selectedRangeStart, selectedRangeEnd);

  @override
  Widget build(BuildContext context) {
    final isClientAvailable = _hasClientRange
        ? roomIsAvailableForRange(room, selectedRangeStart!, selectedRangeEnd!)
        : null;
    final effective = resolveRoomEffectiveState(room);

    return Scaffold(
      appBar: AppBar(
        leadingWidth: 72,
        leading: Padding(
          padding: const EdgeInsets.only(left: AppSpacing.s3),
          child: AppIconButton(
            icon: Icons.arrow_back_rounded,
            tooltip: 'Volver',
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ),
        title: const Text('Detalle de habitacion'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.screen),
          children: [
            _DetailHeader(room: room, role: role, effective: effective),
            const SizedBox(height: AppSpacing.s4),
            _HeroMedia(room: room, effective: effective),
            const SizedBox(height: AppSpacing.s4),
            _GeneralInfoSection(room: room, effective: effective),
            if (role == RoomPageRole.owner) ...[
              const SizedBox(height: AppSpacing.s4),
              _TimelineSection(
                room: room,
                role: role,
                highlighted: highlightOwnerCalendar,
              ),
            ],
            if (role == RoomPageRole.client) ...[
              const SizedBox(height: AppSpacing.s4),
              _ClientAvailabilitySection(
                room: room,
                start: selectedRangeStart,
                end: selectedRangeEnd,
                isAvailable: isClientAvailable,
              ),
            ],
            const SizedBox(height: AppSpacing.s4),
            _ReviewPreviewSection(room: room),
            const SizedBox(height: AppSpacing.s5),
            _ActionBar(
              role: role,
              hasClientRange: _hasClientRange,
              clientIsAvailable: isClientAvailable,
              onReserve: () => _showStub(context, 'Reservar ${room.name}'),
              onViewReviews: () => _showStub(context, 'Ver resenas'),
              onAddReview: () => _showStub(context, 'Agregar resena'),
            ),
          ],
        ),
      ),
    );
  }

  void _showStub(BuildContext context, String action) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$action disponible como accion visual.')),
    );
  }
}

class _DetailHeader extends StatelessWidget {
  const _DetailHeader({
    required this.room,
    required this.role,
    required this.effective,
  });

  final RoomVisualData room;
  final RoomPageRole role;
  final RoomEffectiveState effective;

  @override
  Widget build(BuildContext context) {
    final roleLabel = switch (role) {
      RoomPageRole.admin => 'Solo lectura para administracion',
      RoomPageRole.owner => 'Vista owner con reservas y estados programados',
      RoomPageRole.client => 'Vista cliente con rango de reserva',
    };

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppSpacing.s2,
            runSpacing: AppSpacing.s2,
            children: [
              _InfoPill(
                icon: Icons.door_sliding_outlined,
                label: 'Habitacion ${room.roomNumber}',
              ),
              _InfoPill(
                icon: Icons.toggle_on_outlined,
                label: effective.status.label,
                color: roomOperationalColor(effective.status),
              ),
              _InfoPill(
                icon: Icons.visibility_outlined,
                label: roleLabel,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s3),
          Text(room.name, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: AppSpacing.s2),
          Text(
            room.motelName,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: context.appColors.textSecondary,
                ),
          ),
          const SizedBox(height: AppSpacing.s3),
          Row(
            children: [
              Expanded(
                child: Text(
                  formatPricePerHour(room.pricePerHour),
                  style: AppTextStyles.h2.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              _InfoPill(
                icon: Icons.people_alt_outlined,
                label: '${room.capacity} personas',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroMedia extends StatelessWidget {
  const _HeroMedia({
    required this.room,
    required this.effective,
  });

  final RoomVisualData room;
  final RoomEffectiveState effective;

  @override
  Widget build(BuildContext context) {
    final accent = roomOperationalColor(effective.status);
    return Container(
      height: 260,
      padding: const EdgeInsets.all(AppSpacing.s5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.xxl),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: .20),
            Theme.of(context).colorScheme.primary.withValues(alpha: .12),
            context.appColors.mediaFallback,
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Vista principal',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              Text(
                '${room.imageUrls.length} imagenes dummy',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: context.appColors.textSecondary,
                    ),
              ),
            ],
          ),
          const Spacer(),
          Icon(
            Icons.king_bed_outlined,
            size: 56,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: AppSpacing.s3),
          Text(
            room.imageUrls.isEmpty
                ? 'Sin referencias visuales'
                : room.imageUrls.join('  ·  '),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: context.appColors.textSecondary,
                ),
          ),
        ],
      ),
    );
  }
}

class _GeneralInfoSection extends StatelessWidget {
  const _GeneralInfoSection({
    required this.room,
    required this.effective,
  });

  final RoomVisualData room;
  final RoomEffectiveState effective;

  @override
  Widget build(BuildContext context) {
    final details = [
      ('Motel', room.motelName, Icons.apartment_outlined),
      ('Numero', room.roomNumber, Icons.pin_outlined),
      ('Capacidad', '${room.capacity} personas', Icons.people_outline),
      ('Precio', formatPricePerHour(room.pricePerHour), Icons.payments_outlined),
      ('Estado vigente', effective.status.label, Icons.toggle_on_outlined),
      (
        'Catalogo cliente',
        effective.isActive ? 'Visible' : 'Oculta',
        Icons.visibility_outlined,
      ),
    ];

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Informacion general', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.s3),
          Text(
            room.description,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: context.appColors.textSecondary,
                ),
          ),
          const SizedBox(height: AppSpacing.s4),
          for (final detail in details) ...[
            _DetailRow(label: detail.$1, value: detail.$2, icon: detail.$3),
            if (detail != details.last) const Divider(height: AppSpacing.s5),
          ],
          const SizedBox(height: AppSpacing.s4),
          Text('Servicios incluidos', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.s2),
          Wrap(
            spacing: AppSpacing.s2,
            runSpacing: AppSpacing.s2,
            children: room.includedServices
                .map((service) => _TagPill(label: service))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _TimelineSection extends StatelessWidget {
  const _TimelineSection({
    required this.room,
    required this.role,
    required this.highlighted,
  });

  final RoomVisualData room;
  final RoomPageRole role;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final blocks = buildRoomTimelineBlocks(room);
    final reservations = upcomingReservations(room);
    final statuses = upcomingStatusSchedules(room);
    final title = role == RoomPageRole.owner
        ? 'Calendario operativo'
        : 'Bloques de reserva y estado';
    final summary = role == RoomPageRole.owner
        ? buildOwnerAvailabilityMessage(room)
        : buildAdminReadOnlyMessage(room);

    return AppCard(
      selected: highlighted,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.s2),
          Text(
            summary,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: context.appColors.textSecondary,
                ),
          ),
          const SizedBox(height: AppSpacing.s4),
          if (blocks.isEmpty)
            Text(
              'No hay reservas ni estados programados.',
              style: Theme.of(context).textTheme.bodyMedium,
            )
          else
            ...blocks.map(
              (block) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.s3),
                child: _TimelineTile(block: block),
              ),
            ),
          const SizedBox(height: AppSpacing.s2),
          _CompactSummary(
            title: 'Reservas proximas',
            values: reservations
                .map(
                  (reservation) => formatDateRange(
                    reservation.startDateTime,
                    reservation.endDateTime,
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: AppSpacing.s3),
          _CompactSummary(
            title: 'Estados programados',
            values: statuses
                .map(
                  (status) =>
                      '${status.status.label} · ${formatDateRange(status.startDateTime, status.endDateTime)}',
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _CompactSummary extends StatelessWidget {
  const _CompactSummary({
    required this.title,
    required this.values,
  });

  final String title;
  final List<String> values;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.s3),
      decoration: BoxDecoration(
        color: context.appColors.elevated,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.s2),
          if (values.isEmpty)
            Text(
              'Sin registros proximos',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.appColors.textSecondary,
                  ),
            )
          else
            ...values.take(4).map(
              (value) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.s1),
                child: Text(
                  value,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ClientAvailabilitySection extends StatelessWidget {
  const _ClientAvailabilitySection({
    required this.room,
    required this.start,
    required this.end,
    required this.isAvailable,
  });

  final RoomVisualData room;
  final DateTime? start;
  final DateTime? end;
  final bool? isAvailable;

  @override
  Widget build(BuildContext context) {
    final hasRange = hasDateRange(start, end);
    final totalHours = reservationTotalHours(start, end);
    final totalPrice = reservationTotalPrice(room, start: start, end: end);
    final rangeError = clientReservationRangeError(start, end);
    final effective = resolveRoomEffectiveState(room);
    final color = isAvailable == true
        ? roomOperationalColor(RoomOperationalStatus.available)
        : roomOperationalColor(RoomOperationalStatus.inactive);
    final message = !hasRange
        ? 'Todavia no definiste un rango de reserva.'
        : rangeError ??
            (isAvailable == true
                ? 'Disponible para el rango solicitado.'
                : !effective.isActive
                    ? 'La habitacion no esta activa para reservar en este momento.'
                    : 'El rango cruza con una reserva o bloqueo operativo.');

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Disponibilidad para tu rango',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.s2),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.s3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: .14),
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Text(
              hasRange ? formatDateRange(start!, end!) : 'Sin rango seleccionado',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(color: color),
            ),
          ),
          if (totalHours != null && totalPrice != null) ...[
            const SizedBox(height: AppSpacing.s3),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.s3),
              decoration: BoxDecoration(
                color: context.appColors.elevated,
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: Text(
                'Total estimado: ${formatPriceAmount(totalPrice)} por $totalHours hora${totalHours == 1 ? '' : 's'}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.s3),
          Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: context.appColors.textSecondary,
                ),
          ),
        ],
      ),
    );
  }
}

class _ReviewPreviewSection extends StatelessWidget {
  const _ReviewPreviewSection({required this.room});

  final RoomVisualData room;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Resenas', style: Theme.of(context).textTheme.titleLarge),
              ),
              Text(
                '${room.reviewCount} opiniones',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: context.appColors.textSecondary,
                    ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s3),
          Container(
            padding: const EdgeInsets.all(AppSpacing.s4),
            decoration: BoxDecoration(
              color: context.appColors.elevated,
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.star_rounded, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: AppSpacing.s3),
                Expanded(
                  child: Text(
                    room.reviewSummary,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.role,
    required this.hasClientRange,
    required this.clientIsAvailable,
    required this.onReserve,
    required this.onViewReviews,
    required this.onAddReview,
  });

  final RoomPageRole role;
  final bool hasClientRange;
  final bool? clientIsAvailable;
  final VoidCallback onReserve;
  final VoidCallback onViewReviews;
  final VoidCallback onAddReview;

  @override
  Widget build(BuildContext context) {
    if (role == RoomPageRole.admin) {
      return AppCard(
        child: Text(
          'Vista de solo lectura para administracion. No hay acciones operativas en este rol.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: context.appColors.textSecondary,
              ),
        ),
      );
    }

    if (role == RoomPageRole.owner) {
      return AppCard(
        child: Text(
          'El owner consulta aqui el cruce entre reservas, estados programados y ventanas libres.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: context.appColors.textSecondary,
              ),
        ),
      );
    }

    return Column(
      children: [
        AppButton(
          label: 'Reservar',
          icon: Icons.event_available_outlined,
          onPressed: hasClientRange && clientIsAvailable == true ? onReserve : null,
        ),
        const SizedBox(height: AppSpacing.s3),
        AppButton(
          label: 'Ver resenas',
          icon: Icons.reviews_outlined,
          variant: AppButtonVariant.secondary,
          onPressed: onViewReviews,
        ),
        const SizedBox(height: AppSpacing.s3),
        AppButton(
          label: 'Agregar resena',
          icon: Icons.rate_review_outlined,
          variant: AppButtonVariant.secondary,
          onPressed: onAddReview,
        ),
      ],
    );
  }
}

class _TimelineTile extends StatelessWidget {
  const _TimelineTile({required this.block});

  final RoomTimelineBlock block;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.s3),
      decoration: BoxDecoration(
        color: block.color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            block.label,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: block.color,
                ),
          ),
          const SizedBox(height: AppSpacing.s1),
          Text(block.rangeLabel, style: Theme.of(context).textTheme.bodyMedium),
          if (block.supportingText != null) ...[
            const SizedBox(height: AppSpacing.s1),
            Text(
              block.supportingText!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.appColors.textSecondary,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({
    required this.icon,
    required this.label,
    this.color,
  });

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final foreground = color ?? context.appColors.textSecondary;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: (color ?? context.appColors.elevated).withValues(
          alpha: color == null ? 1 : .14,
        ),
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
            Icon(icon, size: 16, color: foreground),
            const SizedBox(width: AppSpacing.s2),
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: foreground,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TagPill extends StatelessWidget {
  const _TagPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.appColors.elevated,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s3,
          vertical: AppSpacing.s2,
        ),
        child: Text(label, style: Theme.of(context).textTheme.labelMedium),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: context.appColors.textSecondary),
        const SizedBox(width: AppSpacing.s3),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: context.appColors.textSecondary,
                ),
          ),
        ),
        Text(value, style: Theme.of(context).textTheme.titleSmall),
      ],
    );
  }
}
