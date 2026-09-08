import 'package:flutter/material.dart';
import 'package:machuco/core/design_system/tokens/app_colors.dart';
import 'package:machuco/models/room/room_models.dart';

const List<String> roomIncludedServiceCatalog = [
  'Jacuzzi',
  'Smart TV',
  'Wi-Fi',
  'Minibar',
  'Parqueadero',
  'Aire acondicionado',
  'Iluminación ambiental',
  'Room service',
];

const List<RoomOperationalStatus> roomOperationalStatusCatalog = [
  RoomOperationalStatus.available,
  RoomOperationalStatus.reserved,
  RoomOperationalStatus.cleaning,
  RoomOperationalStatus.maintenance,
  RoomOperationalStatus.blocked,
  RoomOperationalStatus.outOfService,
  RoomOperationalStatus.inactive,
  RoomOperationalStatus.active,
];

bool hasDateRange(DateTime? start, DateTime? end) =>
    start != null && end != null && start.isBefore(end);

bool isExactHour(DateTime dateTime) => dateTime.minute == 0;

bool isExactHourRange(DateTime? start, DateTime? end) {
  if (!hasDateRange(start, end) || start == null || end == null) {
    return false;
  }
  if (!isExactHour(start) || !isExactHour(end)) {
    return false;
  }
  return end.difference(start).inMinutes % 60 == 0;
}

int? reservationTotalHours(DateTime? start, DateTime? end) {
  if (!isExactHourRange(start, end) || start == null || end == null) {
    return null;
  }
  final hours = end.difference(start).inHours;
  return hours >= 1 ? hours : null;
}

int? reservationTotalPrice(
  RoomVisualData room, {
  DateTime? start,
  DateTime? end,
}) {
  final totalHours = reservationTotalHours(start, end);
  if (totalHours == null) {
    return null;
  }
  return room.pricePerHour * totalHours;
}

String? clientReservationRangeError(DateTime? start, DateTime? end) {
  if (start == null || end == null) {
    return null;
  }
  if (!isExactHour(start) || !isExactHour(end)) {
    return 'Solo se permiten horas cerradas en punto.';
  }
  if (!start.isBefore(end)) {
    return 'La salida debe ser posterior a la llegada.';
  }
  if (end.difference(start).inMinutes < 60) {
    return 'La reserva minima es de 1 hora exacta.';
  }
  if (end.difference(start).inMinutes % 60 != 0) {
    return 'El intervalo debe ser un numero entero de horas.';
  }
  return null;
}

RoomEffectiveState resolveRoomEffectiveState(
  RoomVisualData room, {
  DateTime? reference,
}) {
  final now = reference ?? DateTime.now();
  final currentSchedule = room.statusSchedules
      .where(
        (schedule) =>
            !now.isBefore(schedule.startDateTime) &&
            now.isBefore(schedule.endDateTime),
      )
      .toList()
    ..sort((a, b) => b.startDateTime.compareTo(a.startDateTime));

  final activeSchedule = currentSchedule.firstOrNull;
  if (activeSchedule == null) {
    return RoomEffectiveState(
      status: room.isActive
          ? RoomOperationalStatus.active
          : RoomOperationalStatus.inactive,
      isActive: room.isActive,
    );
  }

  return RoomEffectiveState(
    status: activeSchedule.status,
    isActive: statusAllowsClientAvailability(activeSchedule.status),
    currentSchedule: activeSchedule,
  );
}

bool statusAllowsClientAvailability(RoomOperationalStatus status) {
  return switch (status) {
    RoomOperationalStatus.available => true,
    RoomOperationalStatus.active => true,
    RoomOperationalStatus.reserved => false,
    RoomOperationalStatus.cleaning => false,
    RoomOperationalStatus.maintenance => false,
    RoomOperationalStatus.blocked => false,
    RoomOperationalStatus.outOfService => false,
    RoomOperationalStatus.inactive => false,
  };
}

bool roomIsAvailableForRange(
  RoomVisualData room,
  DateTime start,
  DateTime end,
) {
  if (clientReservationRangeError(start, end) != null ||
      !resolveRoomEffectiveState(room).isActive) {
    return false;
  }

  final overlapsReservation = room.reservations.any(
    (reservation) =>
        start.isBefore(reservation.endDateTime) &&
        end.isAfter(reservation.startDateTime),
  );
  if (overlapsReservation) {
    return false;
  }

  final overlapsOperationalBlock = room.statusSchedules.any(
    (schedule) =>
        !statusAllowsClientAvailability(schedule.status) &&
        start.isBefore(schedule.endDateTime) &&
        end.isAfter(schedule.startDateTime),
  );
  return !overlapsOperationalBlock;
}

List<RoomTimelineBlock> buildRoomTimelineBlocks(
  RoomVisualData room, {
  DateTime? reference,
  int limit = 6,
}) {
  final now = reference ?? DateTime.now();
  final blocks = <RoomTimelineBlock>[];
  final upcomingReservations = room.reservations
      .where((reservation) => reservation.endDateTime.isAfter(now))
      .toList()
    ..sort((a, b) => a.startDateTime.compareTo(b.startDateTime));
  final upcomingSchedules = room.statusSchedules
      .where((schedule) => schedule.endDateTime.isAfter(now))
      .toList()
    ..sort((a, b) => a.startDateTime.compareTo(b.startDateTime));

  for (final reservation in upcomingReservations) {
    blocks.add(
      RoomTimelineBlock(
        label: reservation.guestName == null
            ? 'Reserva'
            : 'Reserva ${reservation.guestName}',
        rangeLabel:
            formatDateRange(reservation.startDateTime, reservation.endDateTime),
        category: RoomTimelineCategory.reservation,
        color: AppColors.blocked,
        blocksClientAvailability: true,
        supportingText: reservation.state.label,
      ),
    );
  }

  for (final schedule in upcomingSchedules) {
    blocks.add(
      RoomTimelineBlock(
        label: 'Estado ${schedule.status.label}',
        rangeLabel: formatDateRange(schedule.startDateTime, schedule.endDateTime),
        category: RoomTimelineCategory.operational,
        color: roomOperationalColor(schedule.status),
        blocksClientAvailability:
            !statusAllowsClientAvailability(schedule.status),
        supportingText: schedule.supportingText,
      ),
    );
  }

  blocks.sort((a, b) {
    final aStart = _extractBlockStart(a.rangeLabel, room, now, a.label);
    final bStart = _extractBlockStart(b.rangeLabel, room, now, b.label);
    return aStart.compareTo(bStart);
  });

  if (blocks.isEmpty) {
    final effectiveState = resolveRoomEffectiveState(room, reference: now);
    return [
      RoomTimelineBlock(
        label: effectiveState.isActive
            ? 'Sin bloqueos proximos'
            : 'Habitacion no disponible',
        rangeLabel: effectiveState.isActive
            ? 'Disponible para nuevas reservas'
            : 'Actualmente fuera del catalogo cliente',
        category: RoomTimelineCategory.summary,
        color: roomOperationalColor(effectiveState.status),
        blocksClientAvailability: !effectiveState.isActive,
      ),
    ];
  }

  final firstStart = _firstTimelineStart(room, now);
  if (firstStart != null && firstStart.isAfter(now)) {
    blocks.insert(
      0,
      RoomTimelineBlock(
        label: 'Ventana libre',
        rangeLabel: formatDateRange(now, firstStart),
        category: RoomTimelineCategory.freeWindow,
        color: AppColors.available,
        blocksClientAvailability: false,
        supportingText:
            'Sin reservas ni estados de bloqueo antes del siguiente evento.',
      ),
    );
  }

  return blocks.take(limit).toList();
}

DateTime? _firstTimelineStart(RoomVisualData room, DateTime now) {
  final starts = <DateTime>[
    ...room.reservations
        .where((reservation) => reservation.endDateTime.isAfter(now))
        .map((reservation) => reservation.startDateTime),
    ...room.statusSchedules
        .where((schedule) => schedule.endDateTime.isAfter(now))
        .map((schedule) => schedule.startDateTime),
  ]..sort();
  return starts.firstOrNull;
}

DateTime _extractBlockStart(
  String rangeLabel,
  RoomVisualData room,
  DateTime fallback,
  String label,
) {
  for (final reservation in room.reservations) {
    if (label.contains('Reserva') &&
        rangeLabel ==
            formatDateRange(reservation.startDateTime, reservation.endDateTime)) {
      return reservation.startDateTime;
    }
  }
  for (final schedule in room.statusSchedules) {
    if (label == 'Estado ${schedule.status.label}' &&
        rangeLabel == formatDateRange(schedule.startDateTime, schedule.endDateTime)) {
      return schedule.startDateTime;
    }
  }
  return fallback;
}

String buildOwnerAvailabilityMessage(
  RoomVisualData room, {
  DateTime? reference,
}) {
  final now = reference ?? DateTime.now();
  final effectiveState = resolveRoomEffectiveState(room, reference: now);
  if (!effectiveState.isActive) {
    final statusLabel = effectiveState.status.label.toLowerCase();
    return 'No disponible para cliente por estado $statusLabel.';
  }

  final activeReservation = room.reservations.where((reservation) {
    return !now.isBefore(reservation.startDateTime) &&
        now.isBefore(reservation.endDateTime);
  }).firstOrNull;
  if (activeReservation != null) {
    return 'Reservada ahora hasta ${formatDateTime(activeReservation.endDateTime)}.';
  }

  final blockingSchedule = room.statusSchedules.where((schedule) {
    return !statusAllowsClientAvailability(schedule.status) &&
        schedule.startDateTime.isAfter(now);
  }).toList()
    ..sort((a, b) => a.startDateTime.compareTo(b.startDateTime));
  final nextReservation = nearestUpcomingReservation(room, reference: now);

  if (nextReservation == null && blockingSchedule.isEmpty) {
    return 'Disponible ahora y sin reservas o estados proximos.';
  }

  if (nextReservation != null &&
      (blockingSchedule.isEmpty ||
          nextReservation.startDateTime.isBefore(
            blockingSchedule.first.startDateTime,
          ))) {
    return 'Disponible ahora. Proxima reserva ${formatDateRange(nextReservation.startDateTime, nextReservation.endDateTime)}.';
  }

  return 'Disponible ahora. Proximo bloqueo por ${blockingSchedule.first.status.label.toLowerCase()} entre ${formatDateRange(blockingSchedule.first.startDateTime, blockingSchedule.first.endDateTime)}.';
}

String buildAdminReadOnlyMessage(
  RoomVisualData room, {
  DateTime? reference,
}) {
  final effectiveState = resolveRoomEffectiveState(room, reference: reference);
  return 'Estado vigente: ${effectiveState.status.label}. Vista administrativa en solo lectura.';
}

RoomReservationBlock? nearestUpcomingReservation(
  RoomVisualData room, {
  DateTime? reference,
}) {
  final now = reference ?? DateTime.now();
  final upcoming = room.reservations
      .where((reservation) => reservation.endDateTime.isAfter(now))
      .toList()
    ..sort((a, b) => a.startDateTime.compareTo(b.startDateTime));
  return upcoming.firstOrNull;
}

RoomStatusSchedule? nearestUpcomingStatusSchedule(
  RoomVisualData room, {
  DateTime? reference,
}) {
  final now = reference ?? DateTime.now();
  final upcoming = room.statusSchedules
      .where((schedule) => schedule.endDateTime.isAfter(now))
      .toList()
    ..sort((a, b) => a.startDateTime.compareTo(b.startDateTime));
  return upcoming.firstOrNull;
}

List<RoomStatusSchedule> upcomingStatusSchedules(
  RoomVisualData room, {
  DateTime? reference,
}) {
  final now = reference ?? DateTime.now();
  return room.statusSchedules
      .where((schedule) => schedule.endDateTime.isAfter(now))
      .toList()
    ..sort((a, b) => a.startDateTime.compareTo(b.startDateTime));
}

List<RoomReservationBlock> upcomingReservations(
  RoomVisualData room, {
  DateTime? reference,
}) {
  final now = reference ?? DateTime.now();
  return room.reservations
      .where((reservation) => reservation.endDateTime.isAfter(now))
      .toList()
    ..sort((a, b) => a.startDateTime.compareTo(b.startDateTime));
}

String formatPricePerHour(int amount) {
  final formatted = formatPriceAmount(amount);
  return '$formatted/h';
}

String formatPriceAmount(int amount) {
  final digits = amount.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    final position = digits.length - i;
    buffer.write(digits[i]);
    if (position > 1 && position % 3 == 1) {
      buffer.write('.');
    }
  }
  return '\$$buffer';
}

String formatDateTime(DateTime dateTime) {
  final month = _monthName(dateTime.month);
  final day = dateTime.day.toString().padLeft(2, '0');
  final hour = dateTime.hour % 12 == 0 ? 12 : dateTime.hour % 12;
  final minute = dateTime.minute.toString().padLeft(2, '0');
  final suffix = dateTime.hour >= 12 ? 'p. m.' : 'a. m.';
  return '$day $month · $hour:$minute $suffix';
}

String formatDateRange(DateTime start, DateTime end) {
  final sameDay =
      start.year == end.year && start.month == end.month && start.day == end.day;
  if (sameDay) {
    return '${formatDayLabel(start)} · ${formatHour(start)} - ${formatHour(end)}';
  }
  return '${formatDateTime(start)} -> ${formatDateTime(end)}';
}

String formatDayLabel(DateTime dateTime) {
  final month = _monthName(dateTime.month);
  return '${dateTime.day.toString().padLeft(2, '0')} $month';
}

String formatHour(DateTime dateTime) {
  final hour = dateTime.hour % 12 == 0 ? 12 : dateTime.hour % 12;
  final minute = dateTime.minute.toString().padLeft(2, '0');
  final suffix = dateTime.hour >= 12 ? 'p. m.' : 'a. m.';
  return '$hour:$minute $suffix';
}

Color roomAdministrativeColor(bool isActive) =>
    isActive ? AppColors.available : AppColors.blocked;

Color roomOperationalColor(RoomOperationalStatus status) {
  return switch (status) {
    RoomOperationalStatus.available => AppColors.available,
    RoomOperationalStatus.active => AppColors.available,
    RoomOperationalStatus.reserved => AppColors.reserved,
    RoomOperationalStatus.cleaning => AppColors.cleaning,
    RoomOperationalStatus.maintenance => AppColors.maintenance,
    RoomOperationalStatus.blocked => AppColors.blocked,
    RoomOperationalStatus.outOfService => AppColors.blocked,
    RoomOperationalStatus.inactive => AppColors.blocked,
  };
}

String roomAdministrativeLabel(bool isActive) =>
    isActive ? 'Activa' : 'Inactiva';

String roomServiceSummary(RoomVisualData room) {
  if (room.includedServices.isEmpty) {
    return 'Sin servicios incluidos';
  }
  if (room.includedServices.length <= 3) {
    return room.includedServices.join(' · ');
  }
  return '${room.includedServices.take(3).join(' · ')} +${room.includedServices.length - 3}';
}

extension RoomReservationVisualStatePresentation on RoomReservationVisualState {
  String get label => switch (this) {
        RoomReservationVisualState.confirmed => 'Confirmada',
        RoomReservationVisualState.upcoming => 'Proxima',
        RoomReservationVisualState.completed => 'Completada',
      };
}

extension RoomOperationalStatusPresentation on RoomOperationalStatus {
  String get label => switch (this) {
        RoomOperationalStatus.available => 'Disponible',
        RoomOperationalStatus.reserved => 'Reservada',
        RoomOperationalStatus.cleaning => 'Limpieza',
        RoomOperationalStatus.maintenance => 'Mantenimiento',
        RoomOperationalStatus.blocked => 'Bloqueada',
        RoomOperationalStatus.outOfService => 'Fuera de servicio',
        RoomOperationalStatus.inactive => 'Inactiva',
        RoomOperationalStatus.active => 'Activa',
      };
}

String _monthName(int month) {
  return switch (month) {
    1 => 'ene',
    2 => 'feb',
    3 => 'mar',
    4 => 'abr',
    5 => 'may',
    6 => 'jun',
    7 => 'jul',
    8 => 'ago',
    9 => 'sep',
    10 => 'oct',
    11 => 'nov',
    _ => 'dic',
  };
}
