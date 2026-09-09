import 'package:flutter/material.dart';
import 'package:machuco/controllers/room/room_client_controller.dart';
import 'package:machuco/core/design_system/components/app_card.dart';
import 'package:machuco/core/design_system/theme/app_theme_extensions.dart';
import 'package:machuco/core/design_system/tokens/app_radius.dart';
import 'package:machuco/core/design_system/tokens/app_spacing.dart';
import 'package:machuco/models/motel/motel_model.dart';
import 'package:machuco/models/room/room_models.dart';
import 'package:machuco/routes/routes.dart';

class RoomClientPage extends StatefulWidget {
  const RoomClientPage({
    super.key,
    required this.motel,
    this.rooms,
    this.types,
  });
  final Motel motel;
  final List<RoomVisualData>? rooms;
  final List<RoomTypeData>? types;

  @override
  State<RoomClientPage> createState() => _RoomClientPageState();
}

class _RoomClientPageState extends State<RoomClientPage> {
  late final RoomClientController _controller;

  @override
  void initState() {
    super.initState();
    _controller = RoomClientController(
      motelId: widget.motel.id,
      seedRooms: widget.rooms,
      seedTypes: widget.types,
    );
  }

  @override
  Widget build(BuildContext context) {
    final types = _controller.activeRoomTypes;
    return Scaffold(
      appBar: AppBar(title: const Text('Tipos de habitación')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.screen),
          children: [
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cliente',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s1),
                  Text(
                    'Tipos disponibles',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: AppSpacing.s2),
                  Text(
                    'Consulta los tipos que tienen habitaciones activas. La habitación y el horario se asignan al crear la reserva.',
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
              '${types.length} tipos disponibles',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.s3),
            if (types.isEmpty)
              const _EmptyState()
            else
              ...types.map(
                (type) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.s3),
                  child: AppCard(
                    onTap: () {
                      final room = _controller.firstActiveRoomForType(type.id);
                      if (room != null) {
                        Navigator.of(context).pushNamed(
                          AppRoutes.clientCreateBooking,
                          arguments: room,
                        );
                      }
                    },
                    child: Row(
                      children: [
                        Icon(
                          Icons.bedroom_parent_outlined,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: AppSpacing.s3),
                        Expanded(
                          child: Text(
                            type.name,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 16,
                          color: context.appColors.textSecondary,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) => AppCard(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.s5),
      child: Column(
        children: [
          Icon(
            Icons.hotel_class_outlined,
            size: 48,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: AppSpacing.s3),
          Text(
            'No hay tipos disponibles',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.s2),
          Text(
            'Este motel no tiene habitaciones activas para mostrar.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    ),
  );
}
