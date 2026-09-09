import 'package:flutter/material.dart';
import '../../../core/design_system/design_system.dart';
import '../../../models/motel/motel_model.dart'; 
import '../../../controllers/motel/owner_controller/owner_motel_controller.dart'; 
import './../../../routes/routes.dart';
import '../../payment/system_admin_view/admin_payment_page.dart';

class AdminMotelsPage extends StatefulWidget {
  const AdminMotelsPage({super.key});

  @override
  State<AdminMotelsPage> createState() => _AdminMotelsPageState();
}

class _AdminMotelsPageState extends State<AdminMotelsPage> {
  int _selectedIndex = 0; 
  
  final OwnerMotelController _motelController = OwnerMotelController();
  
  List<Motel> _motels = [];
  bool _isLoading = true;

  // Filtro de búsqueda por texto
  String _searchQuery = '';

  // Simulación de administradores o regiones a cargo
  String _currentAdminId = 'admin-root-01';
  final Map<String, String> _dummyAdmins = {
    'admin-root-01': 'Carlos Admin Principal',
    'admin-reg-02': 'Valeria Supervisor Regional',
  };

  @override
  void initState() {
    super.initState();
    _loadMotels();
  }

  Future<void> _loadMotels() async {
    setState(() => _isLoading = true);
    
    // Como los datos base vienen del controlador de moteles, traemos todos o filtramos por el dueño simulado
    final motelesObtenidos = await _motelController.getMotelsByOwnerId('owner-1020304050');
    // Para el admin, podríamos cargar una lista más amplia o combinada si estuviera disponible. 
    // Usamos temporalmente esta lista base para simular la gestión de la plataforma.
    
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
          const Center(child: Text('Panel de Auditoría de Reservas (Admin)')),
          const AdminFinancePage(),
        ],
      ),
      bottomNavigationBar: AppNavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
        },
        destinations: const [
          AppNavigationDestination(
            icon: Icons.admin_panel_settings_outlined,
            selectedIcon: Icons.admin_panel_settings,
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
            label: 'Pagos',
          ),
        ],
      ),
    );
  }

  Widget _buildMotelsContent() {
    // Filtrado local de moteles según el buscador
    final filteredMotels = _motels.where((motel) {
      final nameLower = motel.name.toLowerCase();
      final idLower = motel.id.toLowerCase();
      final query = _searchQuery.toLowerCase();
      return nameLower.contains(query) || idLower.contains(query);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: _currentAdminId,
            dropdownColor: Theme.of(context).cardColor,
            icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
            items: _dummyAdmins.entries.map((entry) {
              return DropdownMenuItem<String>(
                value: entry.key,
                child: Text(
                  entry.value, 
                  style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
                ),
              );
            }).toList(),
            onChanged: (String? newAdminId) {
              if (newAdminId != null && newAdminId != _currentAdminId) {
                setState(() {
                  _currentAdminId = newAdminId;
                });
                _loadMotels();
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
                    'Menú Administrador',
                    style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Sesión: ${_dummyAdmins[_currentAdminId]}',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
            _MenuTile(icon: Icons.security_outlined, title: 'Seguridad y Roles', onTap: () {}),
            _MenuTile(icon: Icons.analytics_outlined, title: 'Reportes Globales', onTap: () {}),
            _MenuTile(
              icon: Icons.support_agent_outlined, 
              title: 'PQRS de Usuarios', 
              onTap: () {
                Navigator.pop(context); 
                // Navigator.pushNamed(context, AppRoutes.adminPqrs);
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
                Text('Gestión de Establecimientos', style: Theme.of(context).textTheme.headlineSmall),
                Chip(
                  label: Text(
                    'Admin Mod',
                    style: const TextStyle(fontSize: 12),
                  ),
                  backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s3),
            // Buscador funcional integrado con el estado
            AppSearchField(
              label: 'Buscar moteles por nombre o ID...',
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
            const SizedBox(height: AppSpacing.s3),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : filteredMotels.isEmpty
                      ? const Center(child: Text('No se encontraron establecimientos registrados.'))
                      : ListView.separated(
                          itemCount: filteredMotels.length,
                          separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.s3),
                          itemBuilder: (context, index) {
                            final motel = filteredMotels[index];
                            return _AdminMotelCard(
                              motel: motel,
                              onToggleStatus: () => _toggleMotelStatus(index),
                              onManage: () {
                                // Navegación de administración profunda o hacia sus productos
                                Navigator.pushNamed(
                                  context,
                                  AppRoutes.ownerProducts,
                                  arguments: motel.id,
                                );
                              },
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Componentes Privados Auxiliares para Admin ---

class _AdminMotelCard extends StatelessWidget {
  const _AdminMotelCard({
    required this.motel,
    required this.onToggleStatus,
    required this.onManage,
  });

  final Motel motel;
  final VoidCallback onToggleStatus;
  final VoidCallback onManage;

  void _showConfirmDialog(BuildContext context) {
    final isActive = motel.isAvailable;
    
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(isActive ? '¿Bloquear motel desde Admin?' : '¿Desbloquear motel?'),
          content: Text(
            isActive
                ? 'Al bloquear "${motel.name}", se restringirá el acceso general en la plataforma de manera administrativa.'
                : 'Al desbloquear "${motel.name}", el establecimiento recuperará su visibilidad pública.',
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
              child: Text(isActive ? 'Sí, bloquear' : 'Sí, desbloquear'),
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
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSpacing.s1),
                Text(
                  'ID: ${motel.id} • NIT: ${motel.nit}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.appColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          StatusBadge(status: isActive ? AppStatus.active : AppStatus.blocked),
          const SizedBox(width: AppSpacing.s2),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            tooltip: 'Opciones de administración',
            onSelected: (String value) {
              if (value == 'gestion') {
                onManage();
              } else if (value == 'bloqueo') {
                _showConfirmDialog(context);
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'gestion',
                child: Row(
                  children: [
                    Icon(Icons.inventory_2_outlined, size: 20),
                    SizedBox(width: 8),
                    Text('Gestionar Productos/Catálogo'),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'bloqueo',
                child: Row(
                  children: [
                    Icon(isActive ? Icons.block : Icons.check_circle_outline, size: 20, color: isActive ? Colors.redAccent : Colors.green),
                    SizedBox(width: 8),
                    Text(isActive ? 'Bloquear establecimiento' : 'Desbloquear establecimiento'),
                  ],
                ),
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