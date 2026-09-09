import 'package:flutter/material.dart';
import 'package:machuco/models/additional_service/additional_service.dart';
import 'package:machuco/models/motel/motel_model.dart';
import 'package:machuco/views/booking/client_view/booking_checkout_page.dart';
import 'package:machuco/views/booking/client_view/reservation_detail_page.dart';
import 'package:machuco/views/booking/client_view/client_reservations_page.dart';
import 'package:machuco/views/booking/client_view/create_booking_page.dart';
import 'package:machuco/views/motel/client_view/client_motels_page.dart';
import 'package:machuco/views/motel/client_view/client_motel_detail_page.dart';
import 'package:machuco/views/additional_service/client_view/add_additional_service_client_page.dart';
import 'package:machuco/views/additional_service/client_view/additional_service_client_page.dart';
import 'package:machuco/views/additional_service/system_admin_view/additional_service_admin_form_page.dart';
import 'package:machuco/views/additional_service/system_admin_view/additional_service_system_administrator_page.dart';
import 'package:machuco/views/owner_management/owner_page.dart';
import 'package:machuco/views/payment/client_view/client_payment_page.dart';
import 'package:machuco/views/payment/owner_view/owner_payment_page.dart';
import 'package:machuco/views/payment/system_admin_view/admin_payment_page.dart';
import 'package:machuco/views/pqrs/PqrsPage.dart';
import 'package:machuco/views/pqrs/client_view/pqrs_page.dart';
import 'package:machuco/views/pqrs/owner_view/pqrs_page.dart';
import 'package:machuco/views/pqrs/system_admin_view/pqrs_page.dart';
import 'package:machuco/views/product/product_list_page.dart';
import 'package:machuco/views/review/review_administration_page.dart';
import 'package:machuco/views/room/room_view_models.dart';

import 'package:machuco/temporal_home_page.dart';

abstract final class  AppRoutes {
  static const home = '/';

  static const temporalHome = '/temporal';

  static const paymentConfirmation = '/payment/client/confirmation';
  static const clientPayments = '/payment/client/history';
  static const ownerPayments = '/payment/owner';
  static const adminPayments = '/payment/admin';
  static const clientAdditionalServices = '/additional-service/client';
  static const addClientAdditionalServices = '/additional-service/client/add';
  static const adminAdditionalServices = '/additional-service/admin';
  static const createAdminAdditionalService = '/additional-service/admin/new';
  static const ownerManagement = '/owner-management';
  static const pqrs = '/pqrs';
  static const clientPqrs = '/pqrs/client';
  static const ownerPqrs = '/pqrs/owner';
  static const adminPqrs = '/pqrs/admin';
  static const clientMotels = '/motels/client';
  static const clientMotelDetail = '/motels/client/detail';
  static const ownerProducts = '/products/owner';
  static const adminReviews = '/reviews/admin';
  static const clientReservations = '/bookings/client';
  static const clientCreateBooking = '/bookings/client/new';
  static const clientBookingCheckout = '/bookings/client/checkout';
  static const clientReservationDetail = '/bookings/client/detail';

  /// Alias conservado para los enlaces existentes desde las reservas.
  static const payment = clientPayments;

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    final Widget page = switch (settings.name) {
      home => TemporalHomePage(),
      clientPayments => const ClientPaymentsPage(),
      ownerPayments => const OwnerPaymentsPage(),
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
      ownerManagement => const OwnerPage(),
      pqrs => const PqrsPage(),
      clientPqrs => const ClientPqrsPage(),
      ownerPqrs => const OwnerPqrsPage(),
      adminPqrs => const SystemAdminPqrsPage(),

      ownerProducts => ProductListView(
        motelId: settings.arguments is String
            ? settings.arguments! as String
            : throw Exception(
          'Se requiere el motelId para acceder a los productos.',
        ),
      ),
      adminReviews => const ReviewAdministrationPage(),

      clientMotels => const ClientMotelsPage(),
      clientMotelDetail => ClientMotelDetailPage(
        motel: settings.arguments is Motel
            ? settings.arguments! as Motel
            : throw Exception(
                'Error: Se requiere pasar un objeto Motel como argumento a esta ruta.',
              ),
      ),

      clientReservations => const ClientReservationsPage(),
      clientCreateBooking => CreateBookingPage(
        room: settings.arguments is RoomVisualData
            ? settings.arguments! as RoomVisualData
            : throw Exception(
                'Error: Se requiere pasar un objeto RoomVisualData como argumento a esta ruta.',
              ),
      ),
      clientBookingCheckout => BookingCheckoutPage(
        reservationId: settings.arguments is String
            ? settings.arguments! as String
            : throw Exception(
                'Error: Se requiere pasar el id de la reserva como argumento a esta ruta.',
              ),
      ),
      clientReservationDetail => ReservationDetailPage(
        reservationId: settings.arguments is String
            ? settings.arguments! as String
            : throw Exception(
                'Error: Se requiere pasar el id de la reserva como argumento a esta ruta.',
              ),
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
