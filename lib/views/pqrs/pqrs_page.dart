import 'package:flutter/material.dart';
import 'package:machuco/controllers/pqrs/pqrs_controller.dart';
import 'package:machuco/core/design_system/design_system.dart';
import 'package:machuco/models/pqrs/pqrs.dart';
import 'package:machuco/widgets/pqrs/pqrs_controller_gate.dart';
import 'client_view/pqrs_page.dart';
import 'owner_view/pqrs_page.dart';
import 'system_admin_view/pqrs_page.dart';

/// Entry point of the PQRS module.
///
/// It routes by the role of the signed-in user: the client sees their
/// requests, the owner the inbox of their motels and the administrator the
/// read-only supervision. Without a session it asks to sign in.
class PqrsPage extends StatelessWidget {
  const PqrsPage({super.key, this.controller});

  /// Injectable for tests; without it the controller of the session is built.
  final PqrsController? controller;

  @override
  Widget build(BuildContext context) {
    return PqrsControllerGate(
      title: 'PQRS',
      controller: controller,
      builder: (context, controller) => switch (controller.role) {
        PqrsActor.client => ClientPqrsPage(controller: controller),
        PqrsActor.owner => OwnerPqrsPage(controller: controller),
        PqrsActor.systemAdmin => SystemAdminPqrsPage(controller: controller),
        null => Scaffold(
          appBar: AppBar(title: const Text('PQRS')),
          body: const AppEmptyState(
            icon: Icons.lock_outline,
            title: 'Debes iniciar sesión',
            message: 'Inicia sesión para consultar tus solicitudes.',
          ),
        ),
      },
    );
  }
}
