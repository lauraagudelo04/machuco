import 'package:machuco/models/room/room_models.dart';

final DateTime roomMockBaseDate = DateTime(2026, 8, 19, 12);

List<RoomVisualData> buildRoomMockData() {
  DateTime at(int dayOffset, int hour, [int minute = 0]) => DateTime(
    roomMockBaseDate.year,
    roomMockBaseDate.month,
    roomMockBaseDate.day + dayOffset,
    hour,
    minute,
  );

  return [
    RoomVisualData(
      id: 'room-101',
      motelId: '1',
      motelName: 'Motel Paraíso Élite',
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
      motelId: '1',
      motelName: 'Motel Paraíso Élite',
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
      motelId: '3',
      motelName: 'Motel Paraíso 3',
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
      motelId: '2',
      motelName: 'Motel El Edén',
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
          supportingText:
              'Bloque administrativo por actualizacion del espacio.',
        ),
        RoomStatusSchedule(
          status: RoomOperationalStatus.active,
          startDateTime: at(4, 8),
          endDateTime: at(8, 8),
          supportingText: 'Reapertura programada al finalizar la intervencion.',
        ),
      ],
      reviewCount: 4,
      reviewSummary:
          'Temporalmente fuera de rotacion, sin incidencias recientes.',
    ),
  ];
}
