import 'package:flutter/material.dart';
import 'package:machuco/controllers/booking_controller.dart';
import 'package:machuco/models/booking.dart';
import 'package:machuco/views/booking/booking_home_page.dart';
import 'package:machuco/views/booking/client_view/booking_detail_page.dart';
import 'package:machuco/views/booking/client_view/client_booking_page.dart';
import 'package:machuco/views/booking/client_view/create_booking_page.dart';
import 'package:machuco/views/booking/owner_view/owner_booking_page.dart';
import 'package:machuco/views/booking/system_admin_view/admin_booking_page.dart';
import 'package:machuco/views/owner_management/owner_page.dart';
import 'package:machuco/views/payment/client/client_payment_page.dart';

abstract final class AppRoutes {
  static const home = '/';
  static const clientBookings = '/booking/client';
  static const createBooking = '/booking/client/create';
  static const bookingDetail = '/booking/client/detail';
  static const ownerBookings = '/booking/owner';
  static const adminBookings = '/booking/admin';
  static const payment = '/payment/client';
  static const ownerManagement = '/owner-management';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    final Widget page = switch (settings.name) {
      home => const BookingHomePage(),
      clientBookings => const ClientBookingPage(),
      createBooking => const CreateBookingPage(),
      bookingDetail => BookingDetailPage(
        booking: settings.arguments is Booking
            ? settings.arguments! as Booking
            : BookingController.clientBookings.first,
      ),
      ownerBookings => const OwnerBookingPage(),
      adminBookings => const AdminBookingPage(),
      payment => const ClientDashboardPage(),
      // El formulario y el detalle de propietarios se navegan dentro del
      // módulo, porque reciben el controlador que tiene su estado.
      ownerManagement => const OwnerPage(),
      _ => const _UnknownRoutePage(),
    };
    return MaterialPageRoute<void>(settings: settings, builder: (_) => page);
  }
}

class _UnknownRoutePage extends StatelessWidget {
  const _UnknownRoutePage();
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Ruta no encontrada')),
    body: Center(
      child: FilledButton(
        onPressed: () => Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.home,
          (_) => false,
        ),
        child: const Text('Volver al inicio'),
      ),
    ),
  );
}
