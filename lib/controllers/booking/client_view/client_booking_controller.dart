import 'package:machuco/models/booking/booking.dart';

/// Provides the booking data required by the client experience.
///
/// The static data is temporary while the persistence contract is defined.
abstract final class ClientBookingController {
  static final List<Booking> bookings = [
    Booking(
      id: 'booking-1048',
      motelId: 'motel-eclipse',
      motelName: 'Motel Eclipse',
      roomName: 'Suite Aurora',
      roomNumber: '101',
      guestName: 'Laura Gómez',
      guestCount: 2,
      checkIn: DateTime(2026, 8, 28, 20),
      checkOut: DateTime(2026, 8, 28, 23),
      total: 204000,
      status: BookingStatus.pendingPayment,
      paymentStatus: BookingPaymentStatus.pending,
      reference: 'MC-1048',
      notes: 'Ingreso privado por parqueadero norte.',
    ),
    Booking(
      id: 'booking-1021',
      motelId: 'motel-eclipse',
      motelName: 'Motel Eclipse',
      roomName: 'Loft Neon',
      roomNumber: '204',
      guestName: 'Laura Gómez',
      guestCount: 2,
      checkIn: DateTime(2026, 8, 19, 18),
      checkOut: DateTime(2026, 8, 19, 21),
      total: 156000,
      status: BookingStatus.completed,
      paymentStatus: BookingPaymentStatus.paid,
      reference: 'MC-1021',
    ),
    Booking(
      id: 'booking-0994',
      motelId: 'motel-luna',
      motelName: 'Luna Roja',
      roomName: 'Suite Cielo',
      roomNumber: '12',
      guestName: 'Laura Gómez',
      guestCount: 2,
      checkIn: DateTime(2026, 7, 30, 22),
      checkOut: DateTime(2026, 7, 31, 1),
      total: 189000,
      status: BookingStatus.cancelled,
      paymentStatus: BookingPaymentStatus.refunded,
      reference: 'MC-0994',
    ),
  ];
}
