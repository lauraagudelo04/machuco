import 'package:flutter/material.dart';
import 'package:machuco/core/design_system/tokens/app_colors.dart';

enum RoomPageRole { admin, owner, client }

enum RoomReservationVisualState { confirmed, upcoming, completed }

enum RoomOperationalStatus {
  available,
  reserved,
  cleaning,
  maintenance,
  blocked,
  outOfService,
  inactive,
  active,
}

enum RoomTimelineCategory { reservation, operational, freeWindow, summary }

class RoomReservationBlock {
  const RoomReservationBlock({
    required this.startDateTime,
    required this.endDateTime,
    this.guestName,
    this.state = RoomReservationVisualState.confirmed,
  });

  final DateTime startDateTime;
  final DateTime endDateTime;
  final String? guestName;
  final RoomReservationVisualState state;

  RoomReservationBlock copyWith({
    DateTime? startDateTime,
    DateTime? endDateTime,
    String? guestName,
    bool clearGuestName = false,
    RoomReservationVisualState? state,
  }) {
    return RoomReservationBlock(
      startDateTime: startDateTime ?? this.startDateTime,
      endDateTime: endDateTime ?? this.endDateTime,
      guestName: clearGuestName ? null : guestName ?? this.guestName,
      state: state ?? this.state,
    );
  }
}

class RoomStatusSchedule {
  const RoomStatusSchedule({
    required this.status,
    required this.startDateTime,
    required this.endDateTime,
    this.supportingText,
  });

  final RoomOperationalStatus status;
  final DateTime startDateTime;
  final DateTime endDateTime;
  final String? supportingText;

  RoomStatusSchedule copyWith({
    RoomOperationalStatus? status,
    DateTime? startDateTime,
    DateTime? endDateTime,
    String? supportingText,
    bool clearSupportingText = false,
  }) {
    return RoomStatusSchedule(
      status: status ?? this.status,
      startDateTime: startDateTime ?? this.startDateTime,
      endDateTime: endDateTime ?? this.endDateTime,
      supportingText: clearSupportingText
          ? null
          : supportingText ?? this.supportingText,
    );
  }
}

class RoomVisualData {
  const RoomVisualData({
    required this.id,
    required this.motelId,
    required this.motelName,
    required this.name,
    required this.description,
    required this.pricePerHour,
    required this.roomNumber,
    required this.capacity,
    required this.imageUrls,
    required this.isActive,
    required this.includedServices,
    required this.reservations,
    required this.statusSchedules,
    this.reviewCount = 0,
    this.reviewSummary = 'Sin reseñas todavía',
  });

  final String id;
  final String motelId;
  final String motelName;
  final String name;
  final String description;
  final int pricePerHour;
  final String roomNumber;
  final int capacity;
  final List<String> imageUrls;
  final bool isActive;
  final List<String> includedServices;
  final List<RoomReservationBlock> reservations;
  final List<RoomStatusSchedule> statusSchedules;
  final int reviewCount;
  final String reviewSummary;

  RoomVisualData copyWith({
    String? id,
    String? motelId,
    String? motelName,
    String? name,
    String? description,
    int? pricePerHour,
    String? roomNumber,
    int? capacity,
    List<String>? imageUrls,
    bool? isActive,
    List<String>? includedServices,
    List<RoomReservationBlock>? reservations,
    List<RoomStatusSchedule>? statusSchedules,
    int? reviewCount,
    String? reviewSummary,
  }) {
    return RoomVisualData(
      id: id ?? this.id,
      motelId: motelId ?? this.motelId,
      motelName: motelName ?? this.motelName,
      name: name ?? this.name,
      description: description ?? this.description,
      pricePerHour: pricePerHour ?? this.pricePerHour,
      roomNumber: roomNumber ?? this.roomNumber,
      capacity: capacity ?? this.capacity,
      imageUrls: imageUrls ?? this.imageUrls,
      isActive: isActive ?? this.isActive,
      includedServices: includedServices ?? this.includedServices,
      reservations: reservations ?? this.reservations,
      statusSchedules: statusSchedules ?? this.statusSchedules,
      reviewCount: reviewCount ?? this.reviewCount,
      reviewSummary: reviewSummary ?? this.reviewSummary,
    );
  }
}

class RoomEffectiveState {
  const RoomEffectiveState({
    required this.status,
    required this.isActive,
    this.currentSchedule,
  });

  final RoomOperationalStatus status;
  final bool isActive;
  final RoomStatusSchedule? currentSchedule;
}

class RoomTimelineBlock {
  const RoomTimelineBlock({
    required this.label,
    required this.rangeLabel,
    required this.category,
    required this.color,
    required this.blocksClientAvailability,
    this.supportingText,
  });

  final String label;
  final String rangeLabel;
  final RoomTimelineCategory category;
  final Color color;
  final bool blocksClientAvailability;
  final String? supportingText;
}

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

final DateTime _mockRoomBaseDate = DateTime(2026, 8, 19, 12);

List<RoomVisualData> buildMockRooms({String motelName = 'Motel Eclipse'}) {
  DateTime at(int dayOffset, int hour, [int minute = 0]) => DateTime(
        _mockRoomBaseDate.year,
        _mockRoomBaseDate.month,
        _mockRoomBaseDate.day + dayOffset,
        hour,
        minute,
      );

  return [
    RoomVisualData(
      id: 'room-101',
      motelId: 'motel-eclipse',
      motelName: motelName,
      name: 'Suite Aurora',
      description:
          'Suite premium con ambientacion calida, acceso privado y enfoque en privacidad.',
      pricePerHour: 68000,
      roomNumber: '101',
      capacity: 2,
      imageUrls: const ['aurora-frontal', 'aurora-jacuzzi'],
      isActive: true,
      includedServices: const ['Jacuzzi', 'Smart TV', 'Wi-Fi'],
      reservations: [
        RoomReservationBlock(
          startDateTime: at(0, 20),
          endDateTime: at(0, 23),
          guestName: 'Laura G.',
          state: RoomReservationVisualState.confirmed,
        ),
        RoomReservationBlock(
          startDateTime: at(1, 9),
          endDateTime: at(1, 12),
          guestName: 'Reserva privada',
          state: RoomReservationVisualState.upcoming,
        ),
      ],
      statusSchedules: [
        RoomStatusSchedule(
          status: RoomOperationalStatus.cleaning,
          startDateTime: at(1, 12),
          endDateTime: at(1, 13, 30),
          supportingText: 'Bloque de alistamiento tras checkout.',
        ),
      ],
      reviewCount: 18,
      reviewSummary: '4.8 promedio en limpieza, privacidad y ambientacion.',
    ),
    RoomVisualData(
      id: 'room-204',
      motelId: 'motel-eclipse',
      motelName: motelName,
      name: 'Loft Neon',
      description:
          'Habitacion moderna con minibar, luces regulables y espacio lounge.',
      pricePerHour: 52000,
      roomNumber: '204',
      capacity: 3,
      imageUrls: const ['neon-principal'],
      isActive: true,
      includedServices: const ['Minibar', 'Wi-Fi', 'Iluminacion ambiental'],
      reservations: [
        RoomReservationBlock(
          startDateTime: at(0, 18),
          endDateTime: at(0, 21),
          guestName: 'Camilo M.',
          state: RoomReservationVisualState.confirmed,
        ),
        RoomReservationBlock(
          startDateTime: at(2, 14),
          endDateTime: at(2, 18),
          guestName: 'Reserva empresa',
          state: RoomReservationVisualState.upcoming,
        ),
      ],
      statusSchedules: [
        RoomStatusSchedule(
          status: RoomOperationalStatus.maintenance,
          startDateTime: at(1, 7),
          endDateTime: at(1, 11),
          supportingText: 'Revision preventiva de iluminacion y sonido.',
        ),
      ],
      reviewCount: 11,
      reviewSummary: 'Muy valorada por ambientacion nocturna y comodidad.',
    ),
    RoomVisualData(
      id: 'room-305',
      motelId: 'motel-eclipse',
      motelName: motelName,
      name: 'Cabina Prisma',
      description:
          'Opcion compacta para reservas agiles con check-in rapido y clima automatico.',
      pricePerHour: 39000,
      roomNumber: '305',
      capacity: 2,
      imageUrls: const ['prisma-exterior', 'prisma-interior'],
      isActive: true,
      includedServices: const ['Wi-Fi', 'Aire acondicionado', 'Smart TV'],
      reservations: [
        RoomReservationBlock(
          startDateTime: at(1, 18),
          endDateTime: at(1, 20),
          guestName: 'Reserva web',
          state: RoomReservationVisualState.upcoming,
        ),
      ],
      statusSchedules: [
        RoomStatusSchedule(
          status: RoomOperationalStatus.available,
          startDateTime: at(0, 12),
          endDateTime: at(0, 18),
          supportingText: 'Franja abierta para reservas de ultima hora.',
        ),
      ],
      reviewCount: 6,
      reviewSummary: 'Buenos comentarios por agilidad de ingreso y precio.',
    ),
    RoomVisualData(
      id: 'room-402',
      motelId: 'motel-eclipse',
      motelName: motelName,
      name: 'Studio Loto',
      description:
          'Unidad versatil para grupos pequenos con apoyo adicional y parqueadero.',
      pricePerHour: 44000,
      roomNumber: '402',
      capacity: 4,
      imageUrls: const ['loto-principal'],
      isActive: false,
      includedServices: const ['Parqueadero', 'Wi-Fi', 'Room service'],
      reservations: [
        RoomReservationBlock(
          startDateTime: at(-1, 19),
          endDateTime: at(-1, 22),
          guestName: 'Reserva cerrada',
          state: RoomReservationVisualState.completed,
        ),
      ],
      statusSchedules: [
        RoomStatusSchedule(
          status: RoomOperationalStatus.inactive,
          startDateTime: at(0, 0),
          endDateTime: at(4, 0),
          supportingText: 'Bloque administrativo por actualizacion del espacio.',
        ),
        RoomStatusSchedule(
          status: RoomOperationalStatus.active,
          startDateTime: at(4, 8),
          endDateTime: at(8, 8),
          supportingText: 'Reapertura programada al finalizar la intervencion.',
        ),
      ],
      reviewCount: 4,
      reviewSummary: 'Temporalmente fuera de rotacion, sin incidencias recientes.',
    ),
  ];
}

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
        supportingText: 'Sin reservas ni estados de bloqueo antes del siguiente evento.',
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

extension on RoomReservationVisualState {
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
