import 'package:flutter/material.dart';
import 'package:machuco/controllers/booking/client_view/client_booking_controller.dart';
import 'package:machuco/controllers/booking/client_view/client_booking_ui_controller.dart';
import 'package:machuco/features/booking/presentation/views/client_home_view.dart';
import 'package:machuco/features/booking/presentation/views/client_pqrs_view.dart';
import 'package:machuco/features/booking/presentation/views/payment_confirmation_view.dart';
import 'package:machuco/features/booking/presentation/views/payment_method_view.dart';
import 'package:machuco/models/booking/booking.dart';
import 'package:machuco/models/booking/booking_checkout_data.dart';
import 'package:machuco/views/booking/booking_home_page.dart';
import 'package:machuco/views/booking/client_view/booking_detail_page.dart';
import 'package:machuco/views/booking/client_view/client_booking_home_page.dart';
import 'package:machuco/views/booking/client_view/create_booking_page.dart';
import 'package:machuco/views/booking/owner_view/owner_booking_home_page.dart';
import 'package:machuco/views/booking/system_admin_view/system_admin_booking_home_page.dart';

enum BookingRole { client, owner, systemAdmin }

abstract final class AppRoutes {
  static const home = '/';
  static const clientBookings = '/booking/client';
  static const clientHome = '/client/home';
  static const clientPqrs = '/client/pqrs';
  static const createBooking = '/booking/client/create';
  static const bookingDetail = '/booking/client/detail';
  static const ownerBookings = '/booking/owner';
  static const systemAdminBookings = '/booking/system-admin';
  static const payment = '/payment/client';
  static const paymentConfirmation = '/payment/client/confirmation';

  static BookingCheckoutData get demoCheckout =>
      ClientBookingUiController.initialCheckout;

  /// Returns the booking entry point for the authenticated user's role.
  static String bookingHomeFor(BookingRole role) => switch (role) {
    BookingRole.client => clientBookings,
    BookingRole.owner => ownerBookings,
    BookingRole.systemAdmin => systemAdminBookings,
  };

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    final Widget page = switch (settings.name) {
      home => const BookingHomePage(),
      clientHome => const ClientHomeView(),
      clientPqrs => const ClientPqrsView(),
      clientBookings => const ClientBookingHomePage(),
      createBooking => const CreateBookingPage(),
      bookingDetail => BookingDetailPage(
        booking: settings.arguments is Booking
            ? settings.arguments! as Booking
            : ClientBookingController.bookings.first,
      ),
      ownerBookings => const OwnerBookingHomePage(),
      systemAdminBookings => const SystemAdminBookingHomePage(),
      payment => PaymentMethodView(
        data: settings.arguments is BookingCheckoutData
            ? settings.arguments! as BookingCheckoutData
            : demoCheckout,
      ),
      paymentConfirmation => _buildPaymentConfirmation(settings.arguments),
      _ => const _UnknownRoutePage(),
    };
    return MaterialPageRoute<void>(settings: settings, builder: (_) => page);
  }

  static Widget _buildPaymentConfirmation(Object? arguments) {
    if (arguments case (
      BookingCheckoutData data,
      BookingPaymentMethod method,
    )) {
      return PaymentConfirmationView(data: data, paymentMethod: method);
    }
    return PaymentConfirmationView(
      data: demoCheckout,
      paymentMethod: BookingPaymentMethod.pse,
    );
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
