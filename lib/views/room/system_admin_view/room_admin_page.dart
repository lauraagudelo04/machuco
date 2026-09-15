import 'package:flutter/material.dart';
import 'package:machuco/controllers/room/room_admin_controller.dart';
import 'package:machuco/controllers/room/room_controller_support.dart';
import 'package:machuco/core/design_system/components/app_card.dart';
import 'package:machuco/core/design_system/components/app_text_field.dart';
import 'package:machuco/core/design_system/theme/app_theme_extensions.dart';
import 'package:machuco/core/design_system/tokens/app_radius.dart';
import 'package:machuco/core/design_system/tokens/app_spacing.dart';
import 'package:machuco/models/motel/motel_model.dart';
import 'package:machuco/models/room/room_models.dart';
import 'package:machuco/views/room/room_detail_page.dart';
import 'package:machuco/views/room/room_status_badge.dart';

/// Consulta de habitaciones para el administrador del sistema.
/// Los tipos se expanden como en la vista de propietario, sin acciones de edición.
class RoomAdminPage extends StatefulWidget {
  const RoomAdminPage({
    super.key,
    required this.motel,
    this.rooms,
    this.types,
  });
  final Motel motel;
  final List<RoomVisualData>? rooms;
  final List<RoomTypeData>? types;

  @override
  State<RoomAdminPage> createState() => _RoomAdminPageState();
}

class _RoomAdminPageState extends State<RoomAdminPage> {
  final _searchController = TextEditingController();
  final Set<String> _expandedTypeIds = <String>{};
  late final RoomAdminController _controller;

  @override
  void initState() {
    super.initState();
    _controller = RoomAdminController(
      motelId: widget.motel.id,
      seedRooms: widget.rooms,
      seedTypes: widget.types,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final types = _controller.roomTypes;
    return Scaffold(
      appBar: AppBar(title: const Text('Habitaciones')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.screen),
          children: [
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Administración',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s1),
                  Text(
                    'Tipos y habitaciones',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: AppSpacing.s2),
                  Text(
                    'Consulta los tipos del motel y despliega sus habitaciones. Esta vista es solo de lectura.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: context.appColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s3),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: context.appColors.elevated,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.s3,
                        vertical: AppSpacing.s2,
                      ),
                      child: Text(widget.motel.name),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.s5),
            Text(
              'Tipos de habitación',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.s3),
            if (types.isEmpty)
              const _AdminEmptyState(
                message: 'No hay tipos registrados para este motel.',
              )
            else ...[
              AppTextField(
                label: 'Buscar habitación',
                controller: _searchController,
                hint: 'Nombre, número o descripción',
                prefixIcon: const Icon(Icons.search),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: AppSpacing.s4),
              ...types.map(
                (type) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.s3),
                  child: _AdminTypeCard(
                    type: type,
                    expanded: _expandedTypeIds.contains(type.id),
                    rooms: _controller.roomsForType(
                      type.id,
                      query: _searchController.text,
                    ),
                    totalRoomCount: _controller.roomsForType(type.id).length,
                    hasSearchQuery: _searchController.text.trim().isNotEmpty,
                    onToggle: () => setState(() {
                      if (!_expandedTypeIds.add(type.id)) {
                        _expandedTypeIds.remove(type.id);
                      }
                    }),
                    onRoomTap: (room) => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => RoomDetailPage(
                          room: room,
                          role: RoomPageRole.admin,
                          typeName: type.name,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AdminTypeCard extends StatelessWidget {
  const _AdminTypeCard({
    required this.type,
    required this.expanded,
    required this.rooms,
    required this.totalRoomCount,
    required this.hasSearchQuery,
    required this.onToggle,
    required this.onRoomTap,
  });
  final RoomTypeData type;
  final bool expanded;
  final List<RoomVisualData> rooms;
  final int totalRoomCount;
  final bool hasSearchQuery;
  final VoidCallback onToggle;
  final ValueChanged<RoomVisualData> onRoomTap;

  @override
  Widget build(BuildContext context) => AppCard(
    onTap: onToggle,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(
              Icons.bedroom_parent_outlined,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: AppSpacing.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    type.name,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppSpacing.s1),
                  Text(
                    '$totalRoomCount ${totalRoomCount == 1 ? 'habitación' : 'habitaciones'}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: context.appColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              expanded
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
              color: context.appColors.textSecondary,
            ),
          ],
        ),
        if (expanded) ...[
          const SizedBox(height: AppSpacing.s3),
          const Divider(),
          const SizedBox(height: AppSpacing.s3),
          Text(
            'Habitaciones de ${type.name}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.s1),
          Text(
            'Toca una habitación para consultar su detalle.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: context.appColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.s3),
          if (rooms.isEmpty)
            _AdminEmptyState(
              message: hasSearchQuery
                  ? 'No hay habitaciones que coincidan con la búsqueda.'
                  : 'No hay habitaciones para este tipo.',
            )
          else
            ...rooms.map(
              (room) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.s3),
                child: _AdminRoomCard(
                  room: room,
                  typeName: type.name,
                  onTap: () => onRoomTap(room),
                ),
              ),
            ),
        ],
      ],
    ),
  );
}

class _AdminRoomCard extends StatelessWidget {
  const _AdminRoomCard({
    required this.room,
    required this.typeName,
    required this.onTap,
  });
  final RoomVisualData room;
  final String typeName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => AppCard(
    onTap: onTap,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                room.name,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            RoomStatusBadge(isActive: room.isActive),
          ],
        ),
        const SizedBox(height: AppSpacing.s1),
        Text(
          '$typeName · Habitación ${room.roomNumber}',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: context.appColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.s3),
        Text(room.description, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: AppSpacing.s3),
        Text(
          '${formatPricePerHour(room.pricePerHour)} · ${room.capacity} personas',
          style: Theme.of(context).textTheme.labelMedium,
        ),
      ],
    ),
  );
}

class _AdminEmptyState extends StatelessWidget {
  const _AdminEmptyState({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => AppCard(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.s4),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: context.appColors.textSecondary,
        ),
      ),
    ),
  );
}
