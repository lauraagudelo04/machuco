import 'package:flutter/material.dart';
import 'package:machuco/controllers/room/room_admin_controller.dart';
import 'package:machuco/controllers/room/room_controller_support.dart';
import 'package:machuco/core/design_system/components/app_card.dart';
import 'package:machuco/core/design_system/components/app_text_field.dart';
import 'package:machuco/core/design_system/theme/app_theme_extensions.dart';
import 'package:machuco/core/design_system/tokens/app_radius.dart';
import 'package:machuco/core/design_system/tokens/app_spacing.dart';
import 'package:machuco/models/room/room_models.dart';
import 'package:machuco/views/room/room_detail_page.dart';

class RoomAdminPage extends StatefulWidget {
  const RoomAdminPage({
    super.key,
    this.rooms,
    this.types,
    this.motelId = '1',
    this.motelName = 'Motel Paraíso Élite',
  });
  final List<RoomVisualData>? rooms;
  final List<RoomTypeData>? types;
  final String motelId;
  final String motelName;

  @override
  State<RoomAdminPage> createState() => _RoomAdminPageState();
}

class _RoomAdminPageState extends State<RoomAdminPage> {
  final _searchController = TextEditingController();
  late final RoomAdminController _controller;
  String? _selectedTypeId;

  @override
  void initState() {
    super.initState();
    _controller = RoomAdminController(
      motelId: widget.motelId,
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
    final selected = types
        .where((type) => type.id == _selectedTypeId)
        .firstOrNull;
    final rooms = selected == null
        ? const <RoomVisualData>[]
        : _controller.roomsForType(selected.id, query: _searchController.text);
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
                    'Consulta en solo lectura los tipos del motel y todas sus habitaciones.',
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
                      child: Text(widget.motelName),
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
            else
              Wrap(
                spacing: AppSpacing.s2,
                runSpacing: AppSpacing.s2,
                children: types
                    .map(
                      (type) => ChoiceChip(
                        label: Text(type.name),
                        selected: type.id == _selectedTypeId,
                        onSelected: (_) =>
                            setState(() => _selectedTypeId = type.id),
                      ),
                    )
                    .toList(),
              ),
            if (selected != null) ...[
              const SizedBox(height: AppSpacing.s5),
              AppTextField(
                label: 'Buscar habitación',
                controller: _searchController,
                hint: 'Nombre, número o descripción',
                prefixIcon: const Icon(Icons.search),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: AppSpacing.s4),
              Text(
                'Habitaciones de ${selected.name}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.s3),
              if (rooms.isEmpty)
                const _AdminEmptyState(
                  message: 'No hay habitaciones para este tipo.',
                )
              else
                ...rooms.map(
                  (room) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.s3),
                    child: _AdminRoomCard(
                      room: room,
                      typeName: selected.name,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => RoomDetailPage(
                            room: room,
                            role: RoomPageRole.admin,
                            typeName: selected.name,
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
            _Status(isActive: room.isActive),
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

class _Status extends StatelessWidget {
  const _Status({required this.isActive});
  final bool isActive;
  @override
  Widget build(BuildContext context) => Text(
    roomAdministrativeLabel(isActive),
    style: Theme.of(context).textTheme.labelMedium?.copyWith(
      color: isActive
          ? Theme.of(context).colorScheme.primary
          : context.appColors.textSecondary,
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
