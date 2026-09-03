import 'package:machuco/controllers/booking/client_view/client_booking_controller.dart';
import 'package:machuco/models/booking/booking.dart';

/// Provides the booking data required by the motel owner experience.
abstract final class OwnerBookingController {
  static final List<Booking> bookings = [
    ...ClientBookingController.bookings,
    Booking(
      id: 'booking-1052',
      motelId: 'motel-eclipse',
      motelName: 'Motel Eclipse',
      roomName: 'Cabina Prisma',
      roomNumber: '305',
      guestName: 'Camilo Martínez',
      guestCount: 2,
      checkIn: DateTime(2026, 8, 29, 14),
      checkOut: DateTime(2026, 8, 29, 18),
      total: 156000,
      status: BookingStatus.confirmed,
      paymentStatus: BookingPaymentStatus.paid,
      reference: 'MC-1052',
    ),
    Booking(
      id: 'booking-1056',
      motelId: 'motel-luna',
      motelName: 'Luna Roja',
      roomName: 'Habitación Deluxe',
      roomNumber: '18',
      guestName: 'Andrea Ruiz',
      guestCount: 2,
      checkIn: DateTime(2026, 8, 30, 19),
      checkOut: DateTime(2026, 8, 30, 22),
      total: 177000,
      status: BookingStatus.confirmed,
      paymentStatus: BookingPaymentStatus.paid,
      reference: 'MC-1056',
    ),
  ];
}
