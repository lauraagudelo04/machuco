import 'package:flutter/material.dart';
import 'package:machuco/core/design_system/design_system.dart';
import 'package:machuco/routes/routes.dart';
import 'package:machuco/views/booking/booking_view_support.dart';
import 'package:machuco/widgets/booking/booking_widgets.dart';
import 'package:machuco/widgets/layout/responsive_content.dart';

class ClientPqrsView extends StatelessWidget {
  const ClientPqrsView({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Mis PQRS')),
    body: SafeArea(
      child: ResponsiveContent(
        maxWidth: 720,
        child: BookingEmptyState(
          title: 'Aún no tienes solicitudes',
          description:
              'Aquí podrás consultar tus peticiones, quejas, reclamos y sugerencias.',
          action: AppButton(
            label: 'Crear una PQRS',
            expanded: false,
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'El formulario de PQRS estará disponible próximamente.',
                ),
              ),
            ),
          ),
        ),
      ),
    ),
    bottomNavigationBar: BookingNavigationBar(
      selectedIndex: 2,
      onSelected: (index) {
        if (index == 0) {
          Navigator.pushReplacementNamed(context, AppRoutes.clientHome);
        }
        if (index == 1) {
          Navigator.pushReplacementNamed(context, AppRoutes.clientBookings);
        }
      },
    ),
  );
}
