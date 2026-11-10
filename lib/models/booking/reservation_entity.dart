import 'package:floor/floor.dart';

/// Floor row for the `reservations` table. It is a persistence shape only:
/// the domain keeps using `Reservation`, and `reservation_mapper.dart`
/// converts between both. Dates are stored as epoch milliseconds and enums
/// as their `name`.
@Entity(
  tableName: 'reservations',
  indices: [
    Index(value: ['requestId']),
    Index(value: ['motelId']),
  ],
)
class ReservationEntity {
  const ReservationEntity({
    required this.id,
    required this.requestId,
    required this.motelId,
    required this.motelName,
    required this.roomId,
    required this.roomName,
    required this.roomNumber,
    required this.checkIn,
    required this.checkOut,
    required this.stayMode,
    required this.guestCount,
    required this.roomTotal,
    required this.total,
    required this.status,
    required this.createdAt,
    required this.guestId,
    required this.guestName,
    required this.categoryId,
    required this.cancellationReason,
    required this.invoiceAccessStatus,
    required this.paymentMethod,
  });

  @PrimaryKey()
  final String id;
  final String requestId;
  final String motelId;
  final String motelName;
  final String roomId;
  final String roomName;
  final String roomNumber;

  /// Epoch milliseconds.
  final int checkIn;

  /// Epoch milliseconds.
  final int checkOut;

  /// `StayMode.name`.
  final String stayMode;
  final int guestCount;
  final int roomTotal;
  final int total;

  /// `ReservationStatus.name`.
  final String status;

  /// Epoch milliseconds.
  final int createdAt;
  final String guestId;
  final String guestName;
  final int? categoryId;
  final String? cancellationReason;

  /// `InvoiceAccessStatus.name`.
  final String invoiceAccessStatus;
  final String? paymentMethod;
}
