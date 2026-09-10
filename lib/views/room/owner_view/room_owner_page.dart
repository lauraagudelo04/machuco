import 'package:flutter/material.dart';
import 'package:machuco/controllers/room/room_controller_support.dart';
import 'package:machuco/controllers/room/room_owner_controller.dart';
import 'package:machuco/core/design_system/components/app_button.dart';
import 'package:machuco/core/design_system/components/app_card.dart';
import 'package:machuco/core/design_system/components/app_text_field.dart';
import 'package:machuco/core/design_system/theme/app_theme_extensions.dart';
import 'package:machuco/core/design_system/tokens/app_radius.dart';
import 'package:machuco/core/design_system/tokens/app_spacing.dart';
import 'package:machuco/models/motel/motel_model.dart';
import 'package:machuco/models/room/room_models.dart';
import 'package:machuco/views/room/room_detail_page.dart';
import 'package:machuco/widgets/layout/responsive_content.dart';

class RoomOwnerPage extends StatefulWidget {
  const RoomOwnerPage({super.key, required this.motel, this.rooms, this.types});
  final Motel motel;
  final List<RoomVisualData>? rooms;
  final List<RoomTypeData>? types;
  @override
  State<RoomOwnerPage> createState() => _RoomOwnerPageState();
}

class _RoomOwnerPageState extends State<RoomOwnerPage> {
  final _searchController = TextEditingController();
  late final RoomOwnerController _controller;
  String? _selectedTypeId;

  @override
  void initState() {
    super.initState();
    _controller = RoomOwnerController(
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
    final selected = types
        .where((type) => type.id == _selectedTypeId)
        .firstOrNull;
    final rooms = selected == null
        ? const <RoomVisualData>[]
        : _controller.roomsForType(selected.id, _searchController.text);
    return Scaffold(
      appBar: AppBar(title: const Text('Habitaciones')),
      body: SafeArea(
        child: ResponsiveContent(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Propietario',
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
                      'Administra los tipos del motel y la información de cada habitación. Reservas controla horarios y disponibilidad.',
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
              _ResponsiveSectionHeader(
                title: 'Tipos de habitación',
                actionLabel: 'Agregar tipo',
                onAction: _createType,
              ),
              const SizedBox(height: AppSpacing.s3),
              if (types.isEmpty)
                const _EmptyState(
                  message: 'Crea un tipo antes de agregar habitaciones.',
                )
              else
                ...types.map(
                  (type) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.s3),
                    child: _OwnerTypeCard(
                      type: type,
                      selected: type.id == _selectedTypeId,
                      onTap: () => setState(() => _selectedTypeId = type.id),
                      onEdit: () => _editType(type),
                      onDelete: () => _deleteType(type),
                    ),
                  ),
                ),
              if (selected != null) ...[
                const SizedBox(height: AppSpacing.s5),
                _ResponsiveSectionHeader(
                  title: 'Habitaciones de ${selected.name}',
                  actionLabel: 'Agregar habitación',
                  onAction: () => _openRoomForm(type: selected),
                ),
                const SizedBox(height: AppSpacing.s3),
                AppTextField(
                  label: 'Buscar habitación',
                  controller: _searchController,
                  hint: 'Nombre, número o servicio',
                  prefixIcon: const Icon(Icons.search),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: AppSpacing.s4),
                if (rooms.isEmpty)
                  const _EmptyState(
                    message: 'No hay habitaciones para este tipo.',
                  )
                else
                  ...rooms.map(
                    (room) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.s3),
                      child: _OwnerRoomCard(
                        room: room,
                        typeName: selected.name,
                        onEdit: () => _openRoomForm(room: room, type: selected),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => RoomDetailPage(
                              room: room,
                              role: RoomPageRole.owner,
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
      ),
    );
  }

  Future<void> _createType() async {
    final name = await _openTypeForm();
    if (name == null) return;
    setState(() {
      final type = RoomTypeData(
        id: 'type-${DateTime.now().millisecondsSinceEpoch}',
        motelId: widget.motel.id,
        name: name,
      );
      _controller.addType(type);
      _selectedTypeId = type.id;
    });
  }

  Future<void> _editType(RoomTypeData type) async {
    final name = await _openTypeForm(initialName: type.name);
    if (name != null) {
      setState(() => _controller.updateType(type.id, name));
    }
  }

  Future<String?> _openTypeForm({String initialName = ''}) {
    final controller = TextEditingController(text: initialName);
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.s5,
          right: AppSpacing.s5,
          top: AppSpacing.s3,
          bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.s5,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              initialName.isEmpty ? 'Agregar tipo' : 'Editar tipo',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.s4),
            AppTextField(
              label: 'Nombre',
              controller: controller,
              hint: 'Suite',
            ),
            const SizedBox(height: AppSpacing.s4),
            AppButton(
              label: 'Guardar',
              onPressed: () {
                final name = controller.text.trim();
                if (name.isNotEmpty) Navigator.of(context).pop(name);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteType(RoomTypeData type) async {
    final count = _controller.roomCountForType(type.id);
    if (count > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No puedes eliminar ${type.name}: tiene $count habitaciones asociadas.',
          ),
        ),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar tipo'),
        content: Text('¿Eliminar ${type.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      setState(() {
        _controller.deleteType(type.id);
        _selectedTypeId = null;
      });
    }
  }

  Future<void> _openRoomForm({
    RoomVisualData? room,
    required RoomTypeData type,
  }) async {
    final name = TextEditingController(text: room?.name ?? '');
    final description = TextEditingController(text: room?.description ?? '');
    final price = TextEditingController(
      text: room == null ? '' : '${room.pricePerHour}',
    );
    final number = TextEditingController(text: room?.roomNumber ?? '');
    final capacity = TextEditingController(
      text: room == null ? '' : '${room.capacity}',
    );
    final imageControllers = (room?.imageUrls ?? const [''])
        .map((image) => TextEditingController(text: image))
        .toList();
    var selectedTypeId = room?.idType ?? type.id;
    var isActive = room?.isActive ?? true;
    var services = List<String>.of(room?.includedServices ?? const []);
    final saved = await showModalBottomSheet<RoomVisualData>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: AppSpacing.s5,
            right: AppSpacing.s5,
            top: AppSpacing.s3,
            bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.s5,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  room == null ? 'Agregar habitación' : 'Editar habitación',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: AppSpacing.s4),
                AppTextField(
                  label: 'Nombre',
                  controller: name,
                  hint: 'Suite Aurora',
                ),
                const SizedBox(height: AppSpacing.s3),
                AppTextField(
                  label: 'Descripción',
                  controller: description,
                  hint: 'Descripción de la habitación',
                  maxLines: 2,
                ),
                const SizedBox(height: AppSpacing.s3),
                AppTextField(
                  label: 'Precio por hora',
                  controller: price,
                  hint: '68000',
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: AppSpacing.s3),
                AppTextField(label: 'Número', controller: number, hint: '101'),
                const SizedBox(height: AppSpacing.s3),
                AppTextField(
                  label: 'Capacidad',
                  controller: capacity,
                  hint: '2',
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: AppSpacing.s3),
                DropdownButtonFormField<String>(
                  initialValue: selectedTypeId,
                  decoration: const InputDecoration(labelText: 'Tipo'),
                  items: _controller.roomTypes
                      .map(
                        (roomType) => DropdownMenuItem(
                          value: roomType.id,
                          child: Text(roomType.name),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setModalState(() => selectedTypeId = value);
                    }
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Habitación activa'),
                  subtitle: const Text('Visible para Reservas'),
                  value: isActive,
                  onChanged: (value) => setModalState(() => isActive = value),
                ),
                Text(
                  'Servicios incluidos',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Wrap(
                  spacing: AppSpacing.s2,
                  runSpacing: AppSpacing.s2,
                  children: roomIncludedServiceCatalog
                      .map(
                        (service) => FilterChip(
                          label: Text(service),
                          selected: services.contains(service),
                          onSelected: (selected) => setModalState(
                            () => selected
                                ? services.add(service)
                                : services.remove(service),
                          ),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: AppSpacing.s4),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Imágenes',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => setModalState(
                        () => imageControllers.add(TextEditingController()),
                      ),
                      icon: const Icon(Icons.add_photo_alternate_outlined),
                      label: const Text('Agregar imagen'),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s2),
                ...List.generate(imageControllers.length, (index) {
                  final imageController = imageControllers[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.s3),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: AppTextField(
                            label: 'Referencia visual ${index + 1}',
                            controller: imageController,
                            hint: 'ej: suite-aurora-1',
                            prefixIcon: const Icon(Icons.image_outlined),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.s2),
                        IconButton(
                          tooltip: 'Eliminar imagen',
                          onPressed: imageControllers.length == 1
                              ? null
                              : () => setModalState(
                                  () => imageControllers.removeAt(index),
                                ),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: AppSpacing.s2),
                AppButton(
                  label: 'Guardar',
                  onPressed: () {
                    final parsedPrice = int.tryParse(price.text.trim()) ?? 0;
                    final parsedCapacity =
                        int.tryParse(capacity.text.trim()) ?? 0;
                    final images = imageControllers
                        .map((controller) => controller.text.trim())
                        .where((reference) => reference.isNotEmpty)
                        .toList();
                    if (name.text.trim().isEmpty ||
                        description.text.trim().isEmpty ||
                        number.text.trim().isEmpty ||
                        parsedPrice <= 0 ||
                        parsedCapacity <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Completa todos los campos principales.',
                          ),
                        ),
                      );
                      return;
                    }
                    Navigator.of(context).pop(
                      RoomVisualData(
                        id:
                            room?.id ??
                            'room-${DateTime.now().millisecondsSinceEpoch}',
                        motelId: widget.motel.id,
                        name: name.text.trim(),
                        description: description.text.trim(),
                        idType: selectedTypeId,
                        pricePerHour: parsedPrice,
                        roomNumber: number.text.trim(),
                        capacity: parsedCapacity,
                        imageUrls: images,
                        isActive: isActive,
                        includedServices: services,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (saved != null) {
      setState(() {
        if (room == null) {
          _controller.addRoom(saved);
        } else {
          _controller.updateRoom(room.id, saved);
        }
      });
    }
  }
}

class _ResponsiveSectionHeader extends StatelessWidget {
  const _ResponsiveSectionHeader({
    required this.title,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final action = AppButton(
        label: actionLabel,
        icon: Icons.add,
        expanded: constraints.maxWidth < 560,
        onPressed: onAction,
      );
      if (constraints.maxWidth < 560) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.s3),
            action,
          ],
        );
      }
      return Row(
        children: [
          Expanded(
            child: Text(title, style: Theme.of(context).textTheme.titleLarge),
          ),
          action,
        ],
      );
    },
  );
}

class _OwnerTypeCard extends StatelessWidget {
  const _OwnerTypeCard({
    required this.type,
    required this.selected,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  final RoomTypeData type;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => AppCard(
    selected: selected,
    onTap: onTap,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final details = Row(
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
        );
        final actions = Wrap(
          spacing: AppSpacing.s2,
          children: [
            TextButton.icon(
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Editar'),
            ),
            TextButton.icon(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline),
              label: const Text('Eliminar'),
            ),
          ],
        );
        if (constraints.maxWidth < 420) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              details,
              const SizedBox(height: AppSpacing.s2),
              actions,
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: details),
            actions,
          ],
        );
      },
    ),
  );
}

class _OwnerRoomCard extends StatelessWidget {
  const _OwnerRoomCard({
    required this.room,
    required this.typeName,
    required this.onEdit,
    required this.onTap,
  });
  final RoomVisualData room;
  final String typeName;
  final VoidCallback onEdit;
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
            Text(
              roomAdministrativeLabel(room.isActive),
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: room.isActive
                    ? Theme.of(context).colorScheme.primary
                    : context.appColors.textSecondary,
              ),
            ),
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
        Text(room.description),
        const SizedBox(height: AppSpacing.s3),
        Text(
          '${formatPricePerHour(room.pricePerHour)} · ${room.capacity} personas',
          style: Theme.of(context).textTheme.labelMedium,
        ),
        const SizedBox(height: AppSpacing.s3),
        TextButton.icon(
          onPressed: onEdit,
          icon: const Icon(Icons.edit_outlined),
          label: const Text('Editar'),
        ),
      ],
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});
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
