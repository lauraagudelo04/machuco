import 'package:flutter/material.dart';
import '../tokens/app_colors.dart';
import '../tokens/app_radius.dart';
import '../tokens/app_spacing.dart';

enum AppStatus { available, reserved, occupied, cleaning, maintenance, blocked, outOfService, active, upcoming, completed, cancelled }
enum StatusBadgeSize { extraSmall, small }

extension AppStatusData on AppStatus {
  String get label => switch (this) { AppStatus.available => 'Disponible', AppStatus.reserved => 'Reservada', AppStatus.occupied => 'Ocupada', AppStatus.cleaning => 'Limpieza', AppStatus.maintenance => 'Mantenimiento', AppStatus.blocked => 'Bloqueada', AppStatus.outOfService => 'Fuera de servicio', AppStatus.active => 'Activa', AppStatus.upcoming => 'Próxima', AppStatus.completed => 'Completada', AppStatus.cancelled => 'Cancelada' };
  Color get color => switch (this) { AppStatus.available || AppStatus.completed => AppColors.available, AppStatus.reserved || AppStatus.upcoming => AppColors.reserved, AppStatus.occupied || AppStatus.active => AppColors.occupied, AppStatus.cleaning => AppColors.cleaning, AppStatus.maintenance => AppColors.maintenance, AppStatus.blocked || AppStatus.outOfService || AppStatus.cancelled => AppColors.blocked };
  IconData get icon => switch (this) { AppStatus.available || AppStatus.completed => Icons.check_circle_outline, AppStatus.reserved || AppStatus.upcoming => Icons.event_outlined, AppStatus.occupied || AppStatus.active => Icons.bed_outlined, AppStatus.cleaning => Icons.cleaning_services_outlined, AppStatus.maintenance => Icons.build_outlined, AppStatus.blocked || AppStatus.outOfService || AppStatus.cancelled => Icons.block_outlined };
}

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status, this.size = StatusBadgeSize.small});
  final AppStatus status; final StatusBadgeSize size;
  @override Widget build(BuildContext context) {
    final compact = size == StatusBadgeSize.extraSmall;
    return Semantics(label: 'Estado: ${status.label}', child: ExcludeSemantics(child: DecoratedBox(
      decoration: BoxDecoration(color: status.color.withValues(alpha: status == AppStatus.outOfService ? .08 : .12), borderRadius: BorderRadius.circular(AppRadius.pill)),
      child: Padding(padding: EdgeInsets.symmetric(horizontal: compact ? AppSpacing.s2 : AppSpacing.s3, vertical: compact ? 3 : AppSpacing.s1), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(status.icon, size: compact ? 14 : 16, color: status.color), const SizedBox(width: AppSpacing.s1), Text(status.label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: status.color))])),
    )));
  }
}
