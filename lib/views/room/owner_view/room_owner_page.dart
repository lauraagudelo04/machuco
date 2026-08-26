import 'package:flutter/material.dart';
import 'package:machuco/core/design_system/components/app_button.dart';
import 'package:machuco/core/design_system/components/app_card.dart';
import 'package:machuco/core/design_system/components/app_text_field.dart';
import 'package:machuco/core/design_system/theme/app_theme_extensions.dart';
import 'package:machuco/core/design_system/tokens/app_radius.dart';
import 'package:machuco/core/design_system/tokens/app_spacing.dart';
import 'package:machuco/views/room/room_detail_page.dart';
import 'package:machuco/views/room/room_view_models.dart';

class RoomOwnerPage extends StatefulWidget {
  const RoomOwnerPage({
    super.key,
    this.rooms,
    this.motelName = 'Motel Eclipse',
  });

  final List<RoomVisualData>? rooms;
  final String motelName;

  @override
  State<RoomOwnerPage> createState() => _RoomOwnerPageState();
}

class _RoomOwnerPageState extends State<RoomOwnerPage> {
  static final DateTime _initialPickerDate = DateTime(2026, 8, 19, 18);

  final TextEditingController _searchController = TextEditingController();
  late List<RoomVisualData> _rooms;

  @override
  void initState() {
    super.initState();
    _rooms = List<RoomVisualData>.from(
      widget.rooms ?? buildMockRooms(motelName: widget.motelName),
    );
  }

  List<RoomVisualData> get _filteredRooms {
    final query = _searchController.text.trim().toLowerCase();
    return _rooms.where((room) {
      final matchesSearch = query.isEmpty ||
          room.name.toLowerCase().contains(query) ||
          room.roomNumber.toLowerCase().contains(query) ||
          room.includedServices.any(
            (service) => service.toLowerCase().contains(query),
          );
      return matchesSearch;
    }).toList();
  }

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
            _OwnerHeader(motelName: widget.motelName),
            const SizedBox(height: AppSpacing.s5),
            _OwnerStatsCard(total: _rooms.length),
            const SizedBox(height: AppSpacing.s5),
            LayoutBuilder(
              builder: (context, constraints) {
                final stacked = constraints.maxWidth < 720;
                if (stacked) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AppTextField(
                        label: 'Buscar habitacion',
                        controller: _searchController,
                        hint: 'Nombre, numero o servicio',
                        prefixIcon: const Icon(Icons.search),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: AppSpacing.s3),
                      AppButton(
                        label: 'Agregar habitacion',
                        icon: Icons.add,
                        onPressed: _createRoom,
                      ),
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: AppTextField(
                        label: 'Buscar habitacion',
                        controller: _searchController,
                        hint: 'Nombre, numero o servicio',
                        prefixIcon: const Icon(Icons.search),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s3),
                    AppButton(
                      label: 'Agregar habitacion',
                      icon: Icons.add,
                      expanded: false,
                      onPressed: _createRoom,
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: AppSpacing.s5),
            if (_rooms.isEmpty)
              const _OwnerEmptyState(
                icon: Icons.meeting_room_outlined,
                title: 'Aun no hay habitaciones',
                description:
                    'Crea la primera habitacion del motel y completa sus servicios e imagenes dummy.',
              )
            else if (_filteredRooms.isEmpty)
              const _OwnerEmptyState(
                icon: Icons.search_off_outlined,
                title: 'No hay coincidencias',
                description:
                    'Prueba otra busqueda por nombre, numero o servicio.',
              )
            else
              ..._filteredRooms.map(
                (room) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.s3),
                  child: _OwnerRoomCard(
                    room: room,
                    onTap: () => _openDetail(room),
                    onEdit: () => _editRoom(room),
                    onChangeStatus: () => _changeRoomStatus(room),
                    onReviews: () => _showStub('Ver resenas de ${room.name}'),
                    onCalendar: () => _openDetail(room, focusCalendar: true),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _createRoom() async {
    final created = await _openRoomForm();
    if (created == null) {
      return;
    }

    setState(() => _rooms = [..._rooms, created]);
  }

  Future<void> _editRoom(RoomVisualData room) async {
    final edited = await _openRoomForm(room: room);
    if (edited == null) {
      return;
    }

    setState(() {
      _rooms = _rooms
          .map((item) => item.id == room.id ? edited.copyWith(id: room.id) : item)
          .toList();
    });
  }

  Future<void> _changeRoomStatus(RoomVisualData room) async {
    var selectedStatus = RoomOperationalStatus.maintenance;
    DateTime startDateTime = DateTime(2026, 8, 19, 19);
    DateTime endDateTime = startDateTime.add(const Duration(hours: 2));
    final noteController = TextEditingController();

    final createdSchedule = await showModalBottomSheet<RoomStatusSchedule>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.s5),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cambiar estado',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: AppSpacing.s2),
                      Text(
                        'Programa un estado operativo con inicio y fin. Se guardara localmente para ${room.name}.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: context.appColors.textSecondary,
                            ),
                      ),
                      const SizedBox(height: AppSpacing.s4),
                      DropdownButtonFormField<RoomOperationalStatus>(
                        initialValue: selectedStatus,
                        decoration: const InputDecoration(
                          labelText: 'Estado',
                        ),
                        items: roomOperationalStatusCatalog
                            .map(
                              (status) => DropdownMenuItem(
                                value: status,
                                child: Text(status.label),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setModalState(() => selectedStatus = value);
                          }
                        },
                      ),
                      const SizedBox(height: AppSpacing.s3),
                      _DateTimeField(
                        label: 'Inicio',
                        value: formatDateTime(startDateTime),
                        icon: Icons.schedule_outlined,
                        onTap: () async {
                          final selected = await _pickDateTime(
                            initial: startDateTime,
                          );
                          if (selected != null) {
                            setModalState(() {
                              startDateTime = selected;
                              if (!startDateTime.isBefore(endDateTime)) {
                                endDateTime =
                                    startDateTime.add(const Duration(hours: 2));
                              }
                            });
                          }
                        },
                      ),
                      const SizedBox(height: AppSpacing.s3),
                      _DateTimeField(
                        label: 'Fin',
                        value: formatDateTime(endDateTime),
                        icon: Icons.event_available_outlined,
                        onTap: () async {
                          final selected = await _pickDateTime(
                            initial: endDateTime,
                            firstDate: startDateTime,
                          );
                          if (selected != null) {
                            setModalState(() => endDateTime = selected);
                          }
                        },
                      ),
                      const SizedBox(height: AppSpacing.s3),
                      AppTextField(
                        label: 'Nota de apoyo',
                        controller: noteController,
                        hint: 'Ej: limpieza profunda antes del siguiente turno',
                        maxLines: 2,
                        prefixIcon: const Icon(Icons.notes_outlined),
                      ),
                      const SizedBox(height: AppSpacing.s4),
                      Row(
                        children: [
                          Expanded(
                            child: AppButton(
                              label: 'Cancelar',
                              variant: AppButtonVariant.secondary,
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.s3),
                          Expanded(
                            child: AppButton(
                              label: 'Guardar estado',
                              onPressed: () {
                                if (!startDateTime.isBefore(endDateTime)) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'El inicio debe ser anterior al fin.',
                                      ),
                                    ),
                                  );
                                  return;
                                }

                                Navigator.of(context).pop(
                                  RoomStatusSchedule(
                                    status: selectedStatus,
                                    startDateTime: startDateTime,
                                    endDateTime: endDateTime,
                                    supportingText:
                                        noteController.text.trim().isEmpty
                                            ? null
                                            : noteController.text.trim(),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (createdSchedule == null) {
      return;
    }

    setState(() {
      _rooms = _rooms.map((item) {
        if (item.id != room.id) {
          return item;
        }
        final nextSchedules = [...item.statusSchedules, createdSchedule]
          ..sort((a, b) => a.startDateTime.compareTo(b.startDateTime));
        return item.copyWith(statusSchedules: nextSchedules);
      }).toList();
    });
  }

  Future<RoomVisualData?> _openRoomForm({RoomVisualData? room}) {
    final isEdit = room != null;
    final nameController = TextEditingController(text: room?.name ?? '');
    final descriptionController = TextEditingController(
      text: room?.description ?? '',
    );
    final priceController = TextEditingController(
      text: room == null ? '' : '${room.pricePerHour}',
    );
    final roomNumberController = TextEditingController(
      text: room?.roomNumber ?? '',
    );
    final capacityController = TextEditingController(
      text: room == null ? '' : '${room.capacity}',
    );
    var selectedServices = List<String>.from(room?.includedServices ?? const []);
    final imageControllers = (room?.imageUrls ?? const [''])
        .map((entry) => TextEditingController(text: entry))
        .toList();

    return showModalBottomSheet<RoomVisualData>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: FractionallySizedBox(
                heightFactor: .94,
                child: SafeArea(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(AppSpacing.s5),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEdit ? 'Editar habitacion' : 'Agregar habitacion',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: AppSpacing.s2),
                        Text(
                          'El mismo formulario se usa para crear o actualizar informacion base, servicios e imagenes dummy.',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: context.appColors.textSecondary,
                              ),
                        ),
                        const SizedBox(height: AppSpacing.s4),
                        AppTextField(
                          label: 'Nombre',
                          controller: nameController,
                          hint: 'Suite Aurora',
                          prefixIcon: const Icon(Icons.title_outlined),
                        ),
                        const SizedBox(height: AppSpacing.s3),
                        AppTextField(
                          label: 'Descripcion',
                          controller: descriptionController,
                          hint: 'Describe la propuesta visual de la habitacion',
                          maxLines: 3,
                          prefixIcon: const Icon(Icons.description_outlined),
                        ),
                        const SizedBox(height: AppSpacing.s3),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final stacked = constraints.maxWidth < 640;
                            final priceField = AppTextField(
                              label: 'Precio por hora',
                              controller: priceController,
                              hint: '68000',
                              keyboardType: TextInputType.number,
                              prefixIcon:
                                  const Icon(Icons.attach_money_outlined),
                            );
                            final roomField = AppTextField(
                              label: 'Numero de habitacion',
                              controller: roomNumberController,
                              hint: '101',
                              prefixIcon: const Icon(Icons.pin_outlined),
                            );
                            if (stacked) {
                              return Column(
                                children: [
                                  priceField,
                                  const SizedBox(height: AppSpacing.s3),
                                  roomField,
                                ],
                              );
                            }
                            return Row(
                              children: [
                                Expanded(child: priceField),
                                const SizedBox(width: AppSpacing.s3),
                                Expanded(child: roomField),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: AppSpacing.s3),
                        AppTextField(
                          label: 'Capacidad maxima',
                          controller: capacityController,
                          hint: '2',
                          keyboardType: TextInputType.number,
                          prefixIcon: const Icon(Icons.people_outline),
                        ),
                        const SizedBox(height: AppSpacing.s4),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(AppSpacing.s3),
                          decoration: BoxDecoration(
                            color: context.appColors.elevated,
                            borderRadius: BorderRadius.circular(AppRadius.lg),
                          ),
                          child: Text(
                            'El estado activa/inactiva se maneja desde "Cambiar estado" con rangos programados, no desde este formulario.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.s4),
                        Text(
                          'Servicios incluidos',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: AppSpacing.s2),
                        Wrap(
                          spacing: AppSpacing.s2,
                          runSpacing: AppSpacing.s2,
                          children: roomIncludedServiceCatalog.map((service) {
                            final selected = selectedServices.contains(service);
                            return FilterChip(
                              label: Text(service),
                              selected: selected,
                              onSelected: (_) {
                                setModalState(() {
                                  if (selected) {
                                    selectedServices.remove(service);
                                  } else {
                                    selectedServices = [
                                      ...selectedServices,
                                      service,
                                    ];
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: AppSpacing.s4),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Imagenes dummy',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () => setModalState(
                                () => imageControllers.add(
                                  TextEditingController(),
                                ),
                              ),
                              icon:
                                  const Icon(Icons.add_photo_alternate_outlined),
                              label: const Text('Agregar imagen'),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.s2),
                        ...List.generate(imageControllers.length, (index) {
                          final controller = imageControllers[index];
                          return Padding(
                            padding:
                                const EdgeInsets.only(bottom: AppSpacing.s3),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Expanded(
                                  child: AppTextField(
                                    label: 'Referencia visual ${index + 1}',
                                    controller: controller,
                                    hint: 'ej: aurora-jacuzzi',
                                    prefixIcon:
                                        const Icon(Icons.image_outlined),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.s2),
                                IconButton(
                                  tooltip: 'Eliminar imagen',
                                  onPressed: imageControllers.length == 1
                                      ? null
                                      : () {
                                          final removedController =
                                              imageControllers[index];
                                          setModalState(
                                            () => imageControllers.removeAt(index),
                                          );
                                          WidgetsBinding.instance
                                              .addPostFrameCallback((_) {
                                            removedController.dispose();
                                          });
                                        },
                                  icon: const Icon(Icons.delete_outline),
                                ),
                              ],
                            ),
                          );
                        }),
                        const SizedBox(height: AppSpacing.s3),
                        Row(
                          children: [
                            Expanded(
                              child: AppButton(
                                label: 'Cancelar',
                                variant: AppButtonVariant.secondary,
                                onPressed: () => Navigator.of(context).pop(),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.s3),
                            Expanded(
                              child: AppButton(
                                label: isEdit
                                    ? 'Guardar cambios'
                                    : 'Crear habitacion',
                                onPressed: () {
                                  final name = nameController.text.trim();
                                  final description =
                                      descriptionController.text.trim();
                                  final price =
                                      int.tryParse(priceController.text.trim()) ??
                                          0;
                                  final roomNumber =
                                      roomNumberController.text.trim();
                                  final capacity = int.tryParse(
                                        capacityController.text.trim(),
                                      ) ??
                                      0;
                                  final cleanedImages = imageControllers
                                      .map((controller) => controller.text.trim())
                                      .where((entry) => entry.isNotEmpty)
                                      .toList();

                                  if (name.isEmpty ||
                                      description.isEmpty ||
                                      roomNumber.isEmpty ||
                                      price <= 0 ||
                                      capacity <= 0) {
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
                                      id: room?.id ??
                                          'room-${DateTime.now().millisecondsSinceEpoch}',
                                      motelId: room?.motelId ?? 'motel-eclipse',
                                      motelName: widget.motelName,
                                      name: name,
                                      description: description,
                                      pricePerHour: price,
                                      roomNumber: roomNumber,
                                      capacity: capacity,
                                      imageUrls: cleanedImages,
                                      isActive: room?.isActive ?? true,
                                      includedServices: selectedServices,
                                      reservations:
                                          room?.reservations ?? const [],
                                      statusSchedules:
                                          room?.statusSchedules ?? const [],
                                      reviewCount: room?.reviewCount ?? 0,
                                      reviewSummary: room?.reviewSummary ??
                                          'Sin resenas todavia',
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.s5),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<DateTime?> _pickDateTime({
    required DateTime initial,
    DateTime? firstDate,
  }) async {
    final minimumDate = firstDate ?? _initialPickerDate;
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(minimumDate) ? minimumDate : initial,
      firstDate: DateTime(minimumDate.year, minimumDate.month, minimumDate.day),
      lastDate: DateTime(2027, 12, 31),
    );
    if (pickedDate == null || !mounted) {
      return null;
    }

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (pickedTime == null || !mounted) {
      return null;
    }

    return DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );
  }

  void _openDetail(RoomVisualData room, {bool focusCalendar = false}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RoomDetailPage(
          room: room,
          role: RoomPageRole.owner,
          highlightOwnerCalendar: focusCalendar,
        ),
      ),
    );
  }

  void _showStub(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

class _OwnerHeader extends StatelessWidget {
  const _OwnerHeader({required this.motelName});

  final String motelName;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Owner',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
          const SizedBox(height: AppSpacing.s1),
          Text(
            'Gestion de habitaciones',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: AppSpacing.s2),
          Text(
            'Administra inventario, consulta reservas proximas y programa estados operativos por rango de fecha y hora.',
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

class _OwnerStatsCard extends StatelessWidget {
  const _OwnerStatsCard({required this.total});

  final int total;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.meeting_room_outlined,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: AppSpacing.s4),
          Text('$total', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: AppSpacing.s1),
          Text(
            'Total de habitaciones',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.s2),
          Text(
            'Inventario cargado localmente para gestion owner.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: context.appColors.textSecondary,
                ),
          ),
        ],
      ),
    );
  }
}

class _OwnerRoomCard extends StatelessWidget {
  const _OwnerRoomCard({
    required this.room,
    required this.onTap,
    required this.onEdit,
    required this.onChangeStatus,
    required this.onReviews,
    required this.onCalendar,
  });

  final RoomVisualData room;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onChangeStatus;
  final VoidCallback onReviews;
  final VoidCallback onCalendar;

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
                    Text(room.name, style: Theme.of(context).textTheme.titleLarge),
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
              _StateBadge(
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
              _MetaChip(
                icon: Icons.payments_outlined,
                text: formatPricePerHour(room.pricePerHour),
              ),
              _MetaChip(
                icon: Icons.people_alt_outlined,
                text: '${room.capacity} personas',
              ),
              _MetaChip(
                icon: Icons.photo_library_outlined,
                text: '${room.imageUrls.length} imagenes',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s3),
          Text(
            roomServiceSummary(room),
            style: Theme.of(context).textTheme.labelMedium,
          ),
          const SizedBox(height: AppSpacing.s4),
          Wrap(
            spacing: AppSpacing.s2,
            runSpacing: AppSpacing.s2,
            children: [
              _ActionChip(
                icon: Icons.edit_outlined,
                label: 'Editar',
                onTap: onEdit,
              ),
              _ActionChip(
                icon: Icons.toggle_on_outlined,
                label: 'Cambiar estado',
                onTap: onChangeStatus,
              ),
              _ActionChip(
                icon: Icons.reviews_outlined,
                label: 'Ver resenas',
                onTap: onReviews,
              ),
              _ActionChip(
                icon: Icons.calendar_month_outlined,
                label: 'Calendario',
                onTap: onCalendar,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DateTimeField extends StatelessWidget {
  const _DateTimeField({
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
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.s3),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: AppSpacing.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: AppSpacing.s1),
                Text(value, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      onPressed: onTap,
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.icon,
    required this.text,
  });

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

class _StateBadge extends StatelessWidget {
  const _StateBadge({
    required this.label,
    required this.color,
  });

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
          style: Theme.of(context).textTheme.labelMedium?.copyWith(color: color),
        ),
      ),
    );
  }
}

class _OwnerEmptyState extends StatelessWidget {
  const _OwnerEmptyState({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s5),
        child: Column(
          children: [
            Icon(icon, size: 48, color: Theme.of(context).colorScheme.primary),
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
