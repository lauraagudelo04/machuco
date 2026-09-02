import 'package:flutter/material.dart';
import 'package:machuco/controllers/booking_controller.dart';
import 'package:machuco/models/additional_service/additional_service.dart';
import 'package:machuco/models/booking.dart';
import 'package:machuco/views/additional_service/client_view/add_additional_service_client_page.dart';
import 'package:machuco/views/additional_service/client_view/additional_service_client_page.dart';
import 'package:machuco/views/additional_service/system_admin_view/additional_service_admin_form_page.dart';
import 'package:machuco/views/additional_service/system_admin_view/additional_service_system_administrator_page.dart';
import 'package:machuco/views/booking/booking_home_page.dart';
import 'package:machuco/views/booking/client_view/booking_detail_page.dart';
import 'package:machuco/views/booking/client_view/client_booking_page.dart';
import 'package:machuco/views/booking/client_view/create_booking_page.dart';
import 'package:machuco/views/booking/owner_view/owner_booking_page.dart';
import 'package:machuco/views/booking/system_admin_view/admin_booking_page.dart';
import 'package:machuco/views/payment/client_view/client_payment_page.dart';
import 'package:machuco/views/payment/owner_view/owner_payment_page.dart';
import 'package:machuco/views/payment/system_admin_view/admin_payment_page.dart';

abstract final class AppRoutes {
  static const home = '/';
  static const clientBookings = '/booking/client';
  static const createBooking = '/booking/client/create';
  static const bookingDetail = '/booking/client/detail';
  static const ownerBookings = '/booking/owner';
  static const adminBookings = '/booking/admin';
  static const clientPayments = '/payment/client';
  static const ownerPayments = '/payment/owner';
  static const adminPayments = '/payment/admin';
  static const clientAdditionalServices = '/additional-service/client';
  static const addClientAdditionalServices = '/additional-service/client/add';
  static const adminAdditionalServices = '/additional-service/admin';
  static const createAdminAdditionalService = '/additional-service/admin/new';

  /// Alias conservado para los enlaces existentes desde las reservas.
  static const payment = clientPayments;

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
      clientPayments => const ClientDashboardPage(),
      ownerPayments => const UserReservationsPage(),
      adminPayments => const AdminFinancePage(),
      clientAdditionalServices => const AdditionalServiceClientPage(),
      addClientAdditionalServices => const AddAdditionalServiceClientPage(),
      adminAdditionalServices =>
        const AdditionalServiceSystemAdministratorPage(),
      createAdminAdditionalService => AdditionalServiceAdminFormPage(
        service: settings.arguments is AdditionalService
            ? settings.arguments! as AdditionalService
            : null,
      ),
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
