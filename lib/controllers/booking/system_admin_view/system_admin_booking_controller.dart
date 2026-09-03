import 'package:machuco/models/booking/booking.dart';

/// Provides the aggregate data required by the system administrator.
abstract final class SystemAdminBookingController {
  static const List<MotelBookingSummary> motelSummaries = [
    MotelBookingSummary(
      motelId: 'motel-eclipse',
      motelName: 'Motel Eclipse',
      city: 'Medellín',
      totalBookings: 184,
      activeBookings: 31,
      cancelledBookings: 12,
      averageBookingsPerDay: 6.1,
      occupancyRate: 78.4,
      totalRevenue: 28450000,
    ),
    MotelBookingSummary(
      motelId: 'motel-luna',
      motelName: 'Luna Roja',
      city: 'Bello',
      totalBookings: 132,
      activeBookings: 24,
      cancelledBookings: 9,
      averageBookingsPerDay: 4.4,
      occupancyRate: 69.2,
      totalRevenue: 19870000,
    ),
    MotelBookingSummary(
      motelId: 'motel-nova',
      motelName: 'Nova Suites',
      city: 'Envigado',
      totalBookings: 96,
      activeBookings: 17,
      cancelledBookings: 15,
      averageBookingsPerDay: 3.2,
      occupancyRate: 54.8,
      totalRevenue: 14200000,
    ),
  ];
}
