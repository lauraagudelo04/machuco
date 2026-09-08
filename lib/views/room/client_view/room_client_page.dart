import 'package:flutter/material.dart';
import 'package:machuco/core/design_system/components/app_button.dart';
import 'package:machuco/core/design_system/components/app_card.dart';
import 'package:machuco/core/design_system/theme/app_theme_extensions.dart';
import 'package:machuco/core/design_system/tokens/app_radius.dart';
import 'package:machuco/core/design_system/tokens/app_spacing.dart';
import 'package:machuco/views/room/room_detail_page.dart';
import 'package:machuco/views/room/room_view_models.dart';

class RoomClientPage extends StatefulWidget {
  const RoomClientPage({
    super.key,
    this.rooms,
    this.motelName = 'Motel Eclipse',
  });

  final List<RoomVisualData>? rooms;
  final String motelName;

  @override
  State<RoomClientPage> createState() => _RoomClientPageState();
}

class _RoomClientPageState extends State<RoomClientPage> {
  static final DateTime _initialPickerDate = DateTime(2026, 8, 19, 18);

  late final List<RoomVisualData> _rooms;
  DateTime? _startDateTime;
  DateTime? _endDateTime;

  String? get _rangeError =>
      clientReservationRangeError(_startDateTime, _endDateTime);

  @override
  void initState() {
    super.initState();
    _rooms = List<RoomVisualData>.from(
      widget.rooms ?? buildMockRooms(motelName: widget.motelName),
    );
  }

  bool get _hasValidRange =>
      reservationTotalHours(_startDateTime, _endDateTime) != null;

  List<RoomVisualData> get _availableRooms {
    if (!_hasValidRange) {
      return const [];
    }

    return _rooms.where((room) {
      return roomIsAvailableForRange(room, _startDateTime!, _endDateTime!);
    }).toList()
      ..sort((a, b) => a.pricePerHour.compareTo(b.pricePerHour));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Habitaciones')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.screen),
          children: [
            _ClientHeader(motelName: widget.motelName),
            const SizedBox(height: AppSpacing.s5),
            _BookingRangeCard(
              startDateTime: _startDateTime,
              endDateTime: _endDateTime,
              rangeError: _rangeError,
              onSelectStart: _selectStartDateTime,
              onSelectEnd: _selectEndDateTime,
              onClear: () => setState(() {
                _startDateTime = null;
                _endDateTime = null;
              }),
            ),
            const SizedBox(height: AppSpacing.s5),
            if (!_hasValidRange)
              _ClientEmptyState(
                icon: _rangeError == null
                    ? Icons.event_note_outlined
                    : Icons.schedule_outlined,
                title: _rangeError == null
                    ? 'Selecciona llegada y salida'
                    : 'Rango no valido',
                description: _rangeError ??
                    'Define un rango en horas exactas. Luego veras solo habitaciones activas y disponibles.',
              )
            else if (_availableRooms.isEmpty)
              const _ClientEmptyState(
                icon: Icons.hotel_class_outlined,
                title: 'No hay disponibilidad para ese rango',
                description:
                    'Prueba otra combinacion de fecha y hora para encontrar habitaciones sin cruces de reserva o bloqueos operativos.',
              )
            else ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Habitaciones reservables',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  Text(
                    '${_availableRooms.length} opciones',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: context.appColors.textSecondary,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s3),
              ..._availableRooms.map(
                (room) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.s3),
                  child: _ClientRoomCard(
                    room: room,
                    selectedRangeLabel:
                        formatDateRange(_startDateTime!, _endDateTime!),
                    totalHours:
                        reservationTotalHours(_startDateTime!, _endDateTime!)!,
                    totalPrice: reservationTotalPrice(
                      room,
                      start: _startDateTime,
                      end: _endDateTime,
                    )!,
                    onTap: () => _openDetail(room),
                    onReserve: () => _openDetail(room),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _selectStartDateTime() async {
    final selected = await _pickDateTime(
      initial: _startDateTime ?? _initialPickerDate,
    );
    if (selected == null) {
      return;
    }

    setState(() {
      _startDateTime = selected;
      if (_endDateTime != null &&
          clientReservationRangeError(_startDateTime, _endDateTime) != null) {
        _endDateTime = null;
      }
    });
  }

  Future<void> _selectEndDateTime() async {
    if (_startDateTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Primero selecciona la fecha y hora de llegada.'),
        ),
      );
      return;
    }

    final selected = await _pickDateTime(
      initial: _endDateTime ?? _startDateTime!.add(const Duration(hours: 2)),
      firstDate: _startDateTime,
    );
    if (selected == null || !mounted) {
      return;
    }

    final rangeError = clientReservationRangeError(_startDateTime, selected);
    if (rangeError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(rangeError)),
      );
      return;
    }

    setState(() => _endDateTime = selected);
  }

  Future<DateTime?> _pickDateTime({
    required DateTime initial,
    DateTime? firstDate,
  }) async {
    final minimumDate = firstDate ?? DateTime(2026, 8, 19);
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(minimumDate) ? minimumDate : initial,
      firstDate: minimumDate,
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

    if (pickedTime.minute != 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Solo se permiten horas cerradas en punto.'),
        ),
      );
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

  void _openDetail(RoomVisualData room) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RoomDetailPage(
          room: room,
          role: RoomPageRole.client,
          selectedRangeStart: _startDateTime,
          selectedRangeEnd: _endDateTime,
        ),
      ),
    );
  }
}

class _ClientHeader extends StatelessWidget {
  const _ClientHeader({required this.motelName});

  final String motelName;

  @override
  Widget build(BuildContext context) {
    return AppCard(
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
            'Reserva por rango de fecha y hora',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: AppSpacing.s2),
          Text(
            'Define llegada y salida para ver unicamente habitaciones activas y disponibles para tu rango.',
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

class _BookingRangeCard extends StatelessWidget {
  const _BookingRangeCard({
    required this.startDateTime,
    required this.endDateTime,
    required this.rangeError,
    required this.onSelectStart,
    required this.onSelectEnd,
    required this.onClear,
  });

  final DateTime? startDateTime;
  final DateTime? endDateTime;
  final String? rangeError;
  final VoidCallback onSelectStart;
  final VoidCallback onSelectEnd;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Rango de reserva',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              if (startDateTime != null || endDateTime != null)
                TextButton(
                  onPressed: onClear,
                  child: const Text('Limpiar'),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.s2),
          Text(
            'Selecciona fecha y hora de llegada y salida en horas exactas.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: context.appColors.textSecondary,
                ),
          ),
          if (rangeError != null) ...[
            const SizedBox(height: AppSpacing.s2),
            Text(
              rangeError!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
            ),
          ],
          const SizedBox(height: AppSpacing.s4),
          LayoutBuilder(
            builder: (context, constraints) {
              final stacked = constraints.maxWidth < 640;
              if (stacked) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _RangeSelectorTile(
                      label: 'Llegada',
                      value: startDateTime == null
                          ? 'Elegir fecha y hora'
                          : formatDateTime(startDateTime!),
                      icon: Icons.login_outlined,
                      onTap: onSelectStart,
                    ),
                    const SizedBox(height: AppSpacing.s3),
                    _RangeSelectorTile(
                      label: 'Salida',
                      value: endDateTime == null
                          ? 'Elegir fecha y hora'
                          : formatDateTime(endDateTime!),
                      icon: Icons.logout_outlined,
                      onTap: onSelectEnd,
                    ),
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _RangeSelectorTile(
                      label: 'Llegada',
                      value: startDateTime == null
                          ? 'Elegir fecha y hora'
                          : formatDateTime(startDateTime!),
                      icon: Icons.login_outlined,
                      onTap: onSelectStart,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s3),
                  Expanded(
                    child: _RangeSelectorTile(
                      label: 'Salida',
                      value: endDateTime == null
                          ? 'Elegir fecha y hora'
                          : formatDateTime(endDateTime!),
                      icon: Icons.logout_outlined,
                      onTap: onSelectEnd,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _RangeSelectorTile extends StatelessWidget {
  const _RangeSelectorTile({
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: AppSpacing.s2),
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: AppSpacing.s1),
          Text(value, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _ClientRoomCard extends StatelessWidget {
  const _ClientRoomCard({
    required this.room,
    required this.selectedRangeLabel,
    required this.totalHours,
    required this.totalPrice,
    required this.onTap,
    required this.onReserve,
  });

  final RoomVisualData room;
  final String selectedRangeLabel;
  final int totalHours;
  final int totalPrice;
  final VoidCallback onTap;
  final VoidCallback onReserve;

  @override
  Widget build(BuildContext context) {
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
                      '${room.motelName} · Habitacion ${room.roomNumber}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: context.appColors.textSecondary,
                          ),
                    ),
                  ],
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: roomOperationalColor(RoomOperationalStatus.available)
                      .withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s3,
                    vertical: AppSpacing.s2,
                  ),
                  child: Text(
                    'Disponible',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: roomOperationalColor(
                            RoomOperationalStatus.available,
                          ),
                        ),
                  ),
                ),
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
              _ClientInfo(
                icon: Icons.payments_outlined,
                text: formatPricePerHour(room.pricePerHour),
              ),
              _ClientInfo(
                icon: Icons.people_outline,
                text: '${room.capacity} personas',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s3),
          Text(
            roomServiceSummary(room),
            style: Theme.of(context).textTheme.labelMedium,
          ),
          const SizedBox(height: AppSpacing.s3),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.s3),
            decoration: BoxDecoration(
              color: context.appColors.elevated,
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Rango elegido: $selectedRangeLabel',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.s1),
                Text(
                  'Total: ${formatPriceAmount(totalPrice)} por $totalHours hora${totalHours == 1 ? '' : 's'}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.s4),
          LayoutBuilder(
            builder: (context, constraints) {
              final stacked = constraints.maxWidth < 440;
              if (stacked) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppButton(
                      label: 'Detalle',
                      icon: Icons.visibility_outlined,
                      variant: AppButtonVariant.secondary,
                      onPressed: onTap,
                    ),
                    const SizedBox(height: AppSpacing.s2),
                    AppButton(
                      label: 'Reservar',
                      icon: Icons.event_available_outlined,
                      onPressed: onReserve,
                    ),
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(
                    child: AppButton(
                      label: 'Detalle',
                      icon: Icons.visibility_outlined,
                      variant: AppButtonVariant.secondary,
                      onPressed: onTap,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s2),
                  Expanded(
                    child: AppButton(
                      label: 'Reservar',
                      icon: Icons.event_available_outlined,
                      onPressed: onReserve,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ClientInfo extends StatelessWidget {
  const _ClientInfo({
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

class _ClientEmptyState extends StatelessWidget {
  const _ClientEmptyState({
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
