import 'package:flutter/material.dart';
import 'package:machuco/core/design_system/design_system.dart';

/// Gestión de administradores: aún no disponible.
class AdministratorsPage extends StatelessWidget {
  const AdministratorsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Administradores')),
      body: const SafeArea(
        child: AppEmptyState(
          icon: Icons.admin_panel_settings_outlined,
          title: 'Próximamente',
          message:
              'Próximamente: la creación de administradores requiere una '
              'función de backend; mientras tanto se asigna el rol desde la '
              'consola de Firebase.',
        ),
      ),
    );
  }
}
