import 'package:flutter/material.dart';

/// Entidad principal del motel dentro del módulo de habitaciones.
///
/// La relación uno-a-muchos se mantiene en las habitaciones mediante su
/// [RoomVisualData.motelId], sin duplicar la lista de habitaciones.
class MotelVisualData {
  const MotelVisualData({required this.id, required this.name});

  /// Identificador único y estable del motel.
  final String id;
  final String name;
}

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
