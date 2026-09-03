import 'package:flutter/material.dart';
import '../../../core/design_system/design_system.dart';
import 'owner_motel_form_page.dart';

class OwnerMotelsPage extends StatefulWidget {
  const OwnerMotelsPage({super.key});

  @override
  State<OwnerMotelsPage> createState() => _OwnerMotelsPageState();
}

class _OwnerMotelsPageState extends State<OwnerMotelsPage> {
  int _selectedIndex = 0; // Para el BottomNavigationBar

  // Lista simulada de moteles en el estado para que el cambio de activo/inhabilitado se refleje en pantalla
  final List<Map<String, dynamic>> _motels = [
    {'name': 'Motel Paraíso 1', 'reservations': 3, 'isActive': true},
    {'name': 'Motel Paraíso 2', 'reservations': 6, 'isActive': true},
    {'name': 'Motel Paraíso 3', 'reservations': 9, 'isActive': false},
  ];

  void _toggleMotelStatus(int index) {
    setState(() {
      _motels[index]['isActive'] = !_motels[index]['isActive'];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Lista Moteles'),
        // Notificaciones a la izquierda
        leadingWidth: 68,
        leading: Padding(
          padding: const EdgeInsets.only(left: AppSpacing.s4),
          child: AppIconButton(
            icon: Icons.notifications_none_outlined,
            tooltip: 'Notificaciones',
            onPressed: () {
              // TODO: Navegar a notificaciones
            },
          ),
        ),
        // Menú de hamburguesa a la derecha
        actions: [
          Builder(
            builder: (context) => Padding(
              padding: const EdgeInsets.only(right: AppSpacing.s4),
              child: AppIconButton(
                icon: Icons.menu,
                tooltip: 'Menú principal',
                onPressed: () => Scaffold.of(context).openEndDrawer(),
              ),
            ),
          ),
        ],
      ),
      // Menú lateral desplegable (Hamburger Menu)
      endDrawer: Drawer(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary, // AppColors.violet
              ),
              child: const Text(
                'Opciones',
                style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ),
            _MenuTile(icon: Icons.star_outline, title: 'Suscripción', onTap: () {}),
            _MenuTile(icon: Icons.person_outline, title: 'Perfil', onTap: () {}),
            _MenuTile(icon: Icons.support_agent_outlined, title: 'PQRS', onTap: () {}),
            _MenuTile(icon: Icons.room_preferences_outlined, title: 'Servicios adicionales', onTap: () {}),
            _MenuTile(icon: Icons.bed_outlined, title: 'Habitaciones', onTap: () {}),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: AppSpacing.s4),
            Text('Tus establecimientos', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: AppSpacing.s3),
            Expanded(
              // Lista de moteles del propietario basada en la lista mutable
              child: ListView.separated(
                itemCount: _motels.length,
                separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.s3),
                itemBuilder: (context, index) {
                  final motel = _motels[index];
                  return _OwnerMotelCard(
                    name: motel['name'],
                    activeReservations: motel['reservations'],
                    isActive: motel['isActive'],
                    onToggleStatus: () => _toggleMotelStatus(index),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      // Botón flotante para Agregar Motel
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const OwnerMotelFormPage(isEditing: false),
            ),
          );
        },
        backgroundColor: Theme.of(context).colorScheme.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Agregar', style: TextStyle(color: Colors.white)),
      ),
      // Barra de navegación inferior
      bottomNavigationBar: AppNavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
        },
        destinations: const [
          AppNavigationDestination(
            icon: Icons.event_note_outlined,
            selectedIcon: Icons.event_note,
            label: 'Reservas',
          ),
          AppNavigationDestination(
            icon: Icons.people_outline,
            selectedIcon: Icons.people,
            label: 'Clientes',
          ),
          AppNavigationDestination(
            icon: Icons.payments_outlined,
            selectedIcon: Icons.payments,
            label: 'Pagos',
          ),
        ],
      ),
    );
  }
}

// --- Componentes Privados Auxiliares ---

class _OwnerMotelCard extends StatelessWidget {
  const _OwnerMotelCard({
    required this.name,
    required this.activeReservations,
    required this.isActive,
    required this.onToggleStatus,
  });

  final String name;
  final int activeReservations;
  final bool isActive;
  final VoidCallback onToggleStatus;

  // Función para mostrar el diálogo de confirmación (Pop-up)
  void _showConfirmDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(isActive ? '¿Inhabilitar motel?' : '¿Habilitar motel?'),
          content: Text(
            isActive
                ? 'Al inhabilitar "$name", los clientes no podrán ver ni realizar nuevas reservas en este establecimiento.'
                : 'Al habilitar "$name", el establecimiento volverá a estar visible y disponible para reservas.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext), // Cierra el pop-up sin hacer nada
              child: const Text('Cancelar'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: isActive ? Colors.redAccent : Colors.green,
              ),
              onPressed: () {
                Navigator.pop(dialogContext); // Cierra el pop-up
                onToggleStatus(); // Ejecuta el cambio de estado
              },
              child: Text(isActive ? 'Sí, inhabilitar' : 'Sí, habilitar'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.s3),
      child: Row(
        children: [
          // Ícono de estado del motel
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isActive ? context.appColors.elevated : context.appColors.mediaFallback,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(
              Icons.domain,
              color: isActive ? Theme.of(context).colorScheme.primary : context.appColors.textDisabled,
            ),
          ),
          const SizedBox(width: AppSpacing.s4),
          // Información del motel
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    decoration: isActive ? null : TextDecoration.lineThrough,
                  ),
                ),
                const SizedBox(height: AppSpacing.s1),
                Text(
                  '$activeReservations reservas activas',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.appColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          // Botones de acción rápida (Editar e Inhabilitar/Habilitar)
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Editar Motel',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const OwnerMotelFormPage(isEditing: true),
                    ),
                  );
                },
              ),
              IconButton(
                icon: Icon(isActive ? Icons.block : Icons.check_circle_outline),
                tooltip: isActive ? 'Inhabilitar Motel' : 'Habilitar Motel',
                color: isActive ? Colors.redAccent : Colors.green,
                onPressed: () => _showConfirmDialog(context), // Llama al pop-up de seguridad
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({required this.icon, required this.title, required this.onTap});
  
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: context.appColors.textSecondary),
      title: Text(title, style: Theme.of(context).textTheme.bodyMedium),
      onTap: onTap,
    );
  }
}