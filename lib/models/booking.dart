enum BookingStatus { pendingPayment, confirmed, completed, cancelled }

enum BookingPaymentStatus { pending, paid, refunded }

class Booking {
  const Booking({
    required this.id,
    required this.motelId,
    required this.motelName,
    required this.roomName,
    required this.roomNumber,
    required this.guestName,
    required this.guestCount,
    required this.checkIn,
    required this.checkOut,
    required this.total,
    required this.status,
    required this.paymentStatus,
    this.reference,
    this.notes,
  });

  final String id;
  final String motelId;
  final String motelName;
  final String roomName;
  final String roomNumber;
  final String guestName;
  final int guestCount;
  final DateTime checkIn;
  final DateTime checkOut;
  final int total;
  final BookingStatus status;
  final BookingPaymentStatus paymentStatus;
  final String? reference;
  final String? notes;

  Booking copyWith({
    BookingStatus? status,
    BookingPaymentStatus? paymentStatus,
  }) {
    return Booking(
      id: id,
      motelId: motelId,
      motelName: motelName,
      roomName: roomName,
      roomNumber: roomNumber,
      guestName: guestName,
      guestCount: guestCount,
      checkIn: checkIn,
      checkOut: checkOut,
      total: total,
      status: status ?? this.status,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      reference: reference,
      notes: notes,
    );
  }
}

class MotelBookingSummary {
  const MotelBookingSummary({
    required this.motelId,
    required this.motelName,
    required this.city,
    required this.totalBookings,
    required this.activeBookings,
    required this.cancelledBookings,
    required this.averageBookingsPerDay,
    required this.occupancyRate,
    required this.totalRevenue,
  });

  final String motelId;
  final String motelName;
  final String city;
  final int totalBookings;
  final int activeBookings;
  final int cancelledBookings;
  final double averageBookingsPerDay;
  final double occupancyRate;
  final int totalRevenue;
}
