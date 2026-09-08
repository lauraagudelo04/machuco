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
    this.motelId = 'motel-eclipse',
    this.motelName = 'Motel Eclipse',
  });

  final List<RoomVisualData>? rooms;
  final String motelId;
  final String motelName;

  @override
  State<RoomAdminPage> createState() => _RoomAdminPageState();
}

class _RoomAdminPageState extends State<RoomAdminPage> {
  final TextEditingController _searchController = TextEditingController();
  late final RoomAdminController _controller;
  bool _sortAscending = true;

  @override
  void initState() {
    super.initState();
    _controller = RoomAdminController(
      motelId: widget.motelId,
      motelName: widget.motelName,
      seedRooms: widget.rooms,
    );
  }

  List<RoomVisualData> get _filteredRooms => _controller.filteredRooms(
    query: _searchController.text,
    sortAscending: _sortAscending,
  );

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Habitaciones')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.screen),
          children: [
            _AdminHeader(motelName: widget.motelName),
            const SizedBox(height: AppSpacing.s5),
            AppTextField(
              label: 'Buscar habitacion',
              controller: _searchController,
              hint: 'Nombre, numero o descripcion',
              prefixIcon: const Icon(Icons.search),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: AppSpacing.s4),
            _AdminSortBar(
              sortAscending: _sortAscending,
              onChanged: (value) => setState(() => _sortAscending = value),
            ),
            const SizedBox(height: AppSpacing.s5),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Listado del motel',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                Text(
                  '${_filteredRooms.length} habitaciones',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: context.appColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s3),
            if (_filteredRooms.isEmpty)
              const _AdminEmptyState(
                title: 'No hay habitaciones para este filtro',
                description:
                    'Prueba con otra busqueda o cambia el orden del listado.',
              )
            else
              ..._filteredRooms.map(
                (room) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.s3),
                  child: _AdminRoomCard(
                    room: room,
                    onTap: () => _openDetail(room),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _openDetail(RoomVisualData room) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RoomDetailPage(room: room, role: RoomPageRole.admin),
      ),
    );
  }
}

class _AdminHeader extends StatelessWidget {
  const _AdminHeader({required this.motelName});

  final String motelName;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Administracion',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: AppSpacing.s1),
          Text(
            'Habitaciones del motel',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: AppSpacing.s2),
          Text(
            'Consulta inventario y estado administrativo efectivo en modo solo lectura.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: context.appColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.s3),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s3,
              vertical: AppSpacing.s2,
            ),
            decoration: BoxDecoration(
              color: context.appColors.elevated,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Text(motelName),
          ),
        ],
      ),
    );
  }
}

class _AdminSortBar extends StatelessWidget {
  const _AdminSortBar({required this.sortAscending, required this.onChanged});

  final bool sortAscending;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.s2,
      runSpacing: AppSpacing.s2,
      children: [
        ChoiceChip(
          label: const Text('A-Z'),
          selected: sortAscending,
          onSelected: (_) => onChanged(true),
        ),
        ChoiceChip(
          label: const Text('Z-A'),
          selected: !sortAscending,
          onSelected: (_) => onChanged(false),
        ),
      ],
    );
  }
}

class _AdminRoomCard extends StatelessWidget {
  const _AdminRoomCard({required this.room, required this.onTap});

  final RoomVisualData room;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final effective = resolveRoomEffectiveState(room);

    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      room.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.s1),
                    Text(
                      'Habitacion ${room.roomNumber} · ${room.motelName}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.appColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              _AdministrativeBadge(
                label: effective.status.label,
                color: roomOperationalColor(effective.status),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s3),
          Text(
            room.description,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: context.appColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.s3),
          Wrap(
            spacing: AppSpacing.s3,
            runSpacing: AppSpacing.s2,
            children: [
              _InfoText(
                icon: Icons.payments_outlined,
                text: formatPricePerHour(room.pricePerHour),
              ),
              _InfoText(
                icon: Icons.people_alt_outlined,
                text: '${room.capacity} personas',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s3),
          Text(
            buildAdminReadOnlyMessage(room),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: context.appColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.s3),
          Text(
            roomServiceSummary(room),
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ],
      ),
    );
  }
}

class _AdministrativeBadge extends StatelessWidget {
  const _AdministrativeBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: .16),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s3,
          vertical: AppSpacing.s2,
        ),
        child: Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelMedium?.copyWith(color: color),
        ),
      ),
    );
  }
}

class _InfoText extends StatelessWidget {
  const _InfoText({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: context.appColors.textSecondary),
        const SizedBox(width: AppSpacing.s2),
        Text(text, style: Theme.of(context).textTheme.labelMedium),
      ],
    );
  }
}

class _AdminEmptyState extends StatelessWidget {
  const _AdminEmptyState({required this.title, required this.description});

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s5),
        child: Column(
          children: [
            Icon(
              Icons.meeting_room_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: AppSpacing.s3),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.s2),
            Text(
              description,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: context.appColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
