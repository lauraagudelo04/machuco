import 'package:flutter/material.dart';
import '../../../core/design_system/design_system.dart';
import '../../../models/motel/motel_model.dart'; 
import '../../../controllers/motel/motel_controller.dart'; 
import 'owner_motel_form_page.dart';
import './../../../routes/routes.dart';
//import '../../booking/owner_view/owner_booking_page.dart';
import '../../payment/owner_view/owner_payment_page.dart';

class OwnerMotelsPage extends StatefulWidget {
  const OwnerMotelsPage({super.key});

  @override
  State<OwnerMotelsPage> createState() => _OwnerMotelsPageState();
}

class _OwnerMotelsPageState extends State<OwnerMotelsPage> {
  int _selectedIndex = 0; 
  
  final MotelController _motelController = MotelController();
  
  List<Motel> _motels = [];
  bool _isLoading = true;

  // Sincronizado con los IDs reales definidos por tu compañero en OwnerController
  String _currentOwnerId = 'owner-1020304050';
  final Map<String, String> _dummyOwners = {
    'owner-1020304050': 'Laura Gómez (Propietaria)',
    'owner-900123456': 'Inversiones Machuco S.A.S.',
    'owner-345678': 'Simón Restrepo',
  };

  @override
  void initState() {
    super.initState();
    _loadMotels();
  }

  Future<void> _loadMotels() async {
    setState(() => _isLoading = true);
    
    // Llamamos al método correcto del controlador pasándole el ID del propietario seleccionado
    final motelesObtenidos = await _motelController.getMotelsByOwnerId(_currentOwnerId);
    
    setState(() {
      _motels = motelesObtenidos;
      _isLoading = false;
    });
  }

  void _toggleMotelStatus(int index) {
    setState(() {
      final current = _motels[index];
      _motels[index] = Motel(
        id: current.id,
        ownerId: current.ownerId,
        name: current.name,
        email: current.email,
        roomCount: current.roomCount,
        nit: current.nit,
        address: current.address,
        phone: current.phone,
        description: current.description,        
        generalLocation: current.generalLocation,   
        paymentMethods: current.paymentMethods,
        imageUrls: current.imageUrls,
        basePrice: current.basePrice,
        isAvailable: !current.isAvailable, 
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildMotelsContent(),
          //const OwnerBookingPage(),
          const OwnerPaymentsPage(),
        ],
      ),
      bottomNavigationBar: AppNavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
        },
        destinations: const [
          AppNavigationDestination(
            icon: Icons.domain_outlined,
            selectedIcon: Icons.domain,
            label: 'Moteles',
          ),
          AppNavigationDestination(
            icon: Icons.event_note_outlined,
            selectedIcon: Icons.event_note,
            label: 'Reservas',
          ),
          AppNavigationDestination(
            icon: Icons.payments_outlined,
            selectedIcon: Icons.payments,
            label: 'Finanzas',
          ),
        ],
      ),
    );
  }

  Widget _buildMotelsContent() {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: _currentOwnerId,
            dropdownColor: Theme.of(context).cardColor,
            icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
            items: _dummyOwners.entries.map((entry) {
              return DropdownMenuItem<String>(
                value: entry.key,
                child: Text(
                  entry.value, 
                  style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
                ),
              );
            }).toList(),
            onChanged: (String? newOwnerId) {
              if (newOwnerId != null && newOwnerId != _currentOwnerId) {
                setState(() {
                  _currentOwnerId = newOwnerId;
                });
                _loadMotels(); // Recarga los moteles dinámicamente según el propietario elegido
              }
            },
          ),
        ),
        leadingWidth: 68,
        leading: Padding(
          padding: const EdgeInsets.only(left: AppSpacing.s4),
          child: AppIconButton(
            icon: Icons.notifications_none_outlined,
            tooltip: 'Notificaciones',
            onPressed: () {},
          ),
        ),
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
      endDrawer: Drawer(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary, 
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Text(
                    'Menú Propietario',
                    style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Sesión: ${_dummyOwners[_currentOwnerId]}',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
            _MenuTile(icon: Icons.star_outline, title: 'Suscripción', onTap: () {}),
            _MenuTile(icon: Icons.person_outline, title: 'Perfil', onTap: () {}),
            _MenuTile(
              icon: Icons.support_agent_outlined, 
              title: 'PQRS', 
              onTap: () {
                Navigator.pop(context); 
                Navigator.pushNamed(context, AppRoutes.ownerPqrs);
              }
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: AppSpacing.s4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Tus establecimientos', style: Theme.of(context).textTheme.headlineSmall),
                Chip(
                  label: Text(
                    _dummyOwners[_currentOwnerId]?.split(' ').first ?? '',
                    style: const TextStyle(fontSize: 12),
                  ),
                  backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s3),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _motels.isEmpty
                      ? const Center(child: Text('Aún no tienes establecimientos registrados.'))
                      : ListView.separated(
                          itemCount: _motels.length,
                          separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.s3),
                          itemBuilder: (context, index) {
                            final motel = _motels[index];
                            return _OwnerMotelCard(
                              motel: motel,
                              activeReservations: 3, 
                              onToggleStatus: () => _toggleMotelStatus(index),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => OwnerMotelFormPage(
                isEditing: false,
                ownerId: _currentOwnerId, // Envía correctamente el ID del propietario activo
              ),
            ),
          ).then((_) => _loadMotels()); // Recarga automáticamente al volver si se registró uno nuevo
        },
        backgroundColor: Theme.of(context).colorScheme.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Agregar', style: TextStyle(color: Colors.white)),
      ),
    );
  }
}

// --- Componentes Privados Auxiliares ---

class _OwnerMotelCard extends StatelessWidget {
  const _OwnerMotelCard({
    required this.motel,
    required this.activeReservations,
    required this.onToggleStatus,
  });

  final Motel motel;
  final int activeReservations;
  final VoidCallback onToggleStatus;

  void _showConfirmDialog(BuildContext context) {
    final isActive = motel.isAvailable;
    
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(isActive ? '¿Inhabilitar motel?' : '¿Habilitar motel?'),
          content: Text(
            isActive
                ? 'Al inhabilitar "${motel.name}", los clientes no podrán ver ni realizar nuevas reservas en este establecimiento.'
                : 'Al habilitar "${motel.name}", el establecimiento volverá a estar visible y disponible para reservas.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext), 
              child: const Text('Cancelar'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: isActive ? Colors.redAccent : Colors.green,
              ),
              onPressed: () {
                Navigator.pop(dialogContext); 
                onToggleStatus(); 
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
    final isActive = motel.isAvailable;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.s3),
      child: Row(
        children: [
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  motel.name,
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
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Editar Motel',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => OwnerMotelFormPage(
                        isEditing: true, 
                        motel: motel,
                        ownerId: motel.ownerId,
                      ),
                    ),
                  );
                },
              ),
              IconButton(
                icon: Icon(isActive ? Icons.block : Icons.check_circle_outline),
                tooltip: isActive ? 'Inhabilitar Motel' : 'Habilitar Motel',
                color: isActive ? Colors.redAccent : Colors.green,
                onPressed: () => _showConfirmDialog(context), 
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                tooltip: 'Gestionar establecimiento',
                onSelected: (String value) {
                  if (value == 'productos') {
                    // Navegamos a la vista de productos enviando el id del motel como argumento
                    Navigator.pushNamed(
                      context,
                      AppRoutes.ownerProducts,
                      arguments: motel.id,
                    );
                  } else if (value == 'habitaciones') {
                    // TODO: Implementar navegación a habitaciones cuando esté lista
                  } else if (value == 'servicios') {
                    // TODO: Implementar navegación a servicios adicionales cuando esté lista
                  }
                },
                itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                  const PopupMenuItem<String>(
                    value: 'habitaciones',
                    child: Row(
                      children: [
                        Icon(Icons.bed_outlined, size: 20),
                        SizedBox(width: 8),
                        Text('Habitaciones'),
                      ],
                    ),
                  ),
                  const PopupMenuItem<String>(
                    value: 'productos',
                    child: Row(
                      children: [
                        Icon(Icons.inventory_2_outlined, size: 20),
                        SizedBox(width: 8),
                        Text('Productos'),
                      ],
                    ),
                  ),
                  const PopupMenuItem<String>(
                    value: 'servicios',
                    child: Row(
                      children: [
                        Icon(Icons.room_preferences_outlined, size: 20),
                        SizedBox(width: 8),
                        Text('Servicios adicionales'),
                      ],
                    ),
                  ),
                ],
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