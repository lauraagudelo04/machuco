import 'package:flutter/material.dart';
import 'package:machuco/controllers/room/room_controller_support.dart';
import 'package:machuco/core/design_system/components/app_card.dart';
import 'package:machuco/core/design_system/theme/app_theme_extensions.dart';
import 'package:machuco/core/design_system/tokens/app_radius.dart';
import 'package:machuco/core/design_system/tokens/app_spacing.dart';
import 'package:machuco/models/room/room_models.dart';

/// Detalle de datos maestros. Disponibilidad y reseñas viven en sus módulos.
class RoomDetailPage extends StatelessWidget {
  const RoomDetailPage({
    super.key,
    required this.room,
    required this.role,
    this.typeName,
  });
  final RoomVisualData room;
  final RoomPageRole role;
  final String? typeName;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Detalle de habitación')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.screen),
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        room.name,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                    ),
                    _ActiveBadge(isActive: room.isActive),
                  ],
                ),
                const SizedBox(height: AppSpacing.s2),
                Text(
                  'Habitación ${room.roomNumber}${typeName == null ? '' : ' · $typeName'}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: context.appColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.s4),
                Text(
                  room.description,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.s4),
                _InfoRow(
                  icon: Icons.payments_outlined,
                  label: 'Precio',
                  value: formatPricePerHour(room.pricePerHour),
                ),
                _InfoRow(
                  icon: Icons.people_alt_outlined,
                  label: 'Capacidad',
                  value: '${room.capacity} personas',
                ),
                _InfoRow(
                  icon: Icons.image_outlined,
                  label: 'Imágenes',
                  value: '${room.imageUrls.length} referencias',
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.s4),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Servicios incluidos',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.s3),
                Wrap(
                  spacing: AppSpacing.s2,
                  runSpacing: AppSpacing.s2,
                  children: room.includedServices
                      .map(
                        (service) => DecoratedBox(
                          decoration: BoxDecoration(
                            color: context.appColors.elevated,
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.s3,
                              vertical: AppSpacing.s2,
                            ),
                            child: Text(service),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.s4),
          AppCard(
            child: Text(
              'La disponibilidad y los horarios se validan en Reservas. Las reseñas se consultan desde el módulo Reviews.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: context.appColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _ActiveBadge extends StatelessWidget {
  const _ActiveBadge({required this.isActive});
  final bool isActive;
  @override
  Widget build(BuildContext context) {
    final color = isActive
        ? Theme.of(context).colorScheme.primary
        : context.appColors.textSecondary;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s3,
          vertical: AppSpacing.s2,
        ),
        child: Text(
          roomAdministrativeLabel(isActive),
          style: Theme.of(
            context,
          ).textTheme.labelMedium?.copyWith(color: color),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.s3),
    child: Row(
      children: [
        Icon(icon, color: context.appColors.textSecondary),
        const SizedBox(width: AppSpacing.s3),
        Text('$label: ', style: Theme.of(context).textTheme.titleSmall),
        Expanded(child: Text(value, textAlign: TextAlign.end)),
      ],
    ),
  );
}
