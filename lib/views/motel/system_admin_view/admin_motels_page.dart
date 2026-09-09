import 'package:flutter/material.dart';
import '../../../core/design_system/design_system.dart';
import '../../../models/motel/motel_model.dart'; 
import '../../../models/owner_management/owner.dart';
import '../../../models/owner_management/document_type.dart';
import '../../../controllers/motel/motel_controller.dart'; 
import '../../../controllers/owner_management/owner_controller.dart'; 
import './../../../routes/routes.dart';
import '../../payment/system_admin_view/admin_payment_page.dart';
import './admin_motel_form_page.dart'; 

// admin_motels_page.dart

class AdminMotelsPage extends StatefulWidget {
  final String? initialOwnerId;
  final String? initialOwnerName;

  const AdminMotelsPage({
    super.key,
    this.initialOwnerId,
    this.initialOwnerName,
  });

  @override
  State<AdminMotelsPage> createState() => _AdminMotelsPageState();
}

class _AdminMotelsPageState extends State<AdminMotelsPage> {
  int _selectedIndex = 0; 
  
  final MotelController _motelController = MotelController();
  final OwnerController _ownerController = OwnerController();
  
  List<Motel> _motels = [];
  List<Owner> _owners = [];
  bool _isLoading = true;

  String _searchQuery = '';

  late String _currentOwnerId;

  @override
  void initState() {
    super.initState();
    _loadOwnersAndMotels();
  }

  Future<void> _loadOwnersAndMotels() async {
    setState(() => _isLoading = true);
    
    final ownersList = _ownerController.owners;
    _owners = ownersList;
    
    if (widget.initialOwnerId != null && widget.initialOwnerId!.isNotEmpty) {
      _currentOwnerId = widget.initialOwnerId!;
    } else if (_owners.isNotEmpty) {
      _currentOwnerId = _owners.first.id;
    } else {
      _currentOwnerId = 'owner-1020304050'; 
    }

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

  Future<void> _showMotelFormModal({Motel? motelToEdit}) async {
    final isEditing = motelToEdit != null;

    final result = await Navigator.push<Motel>(
      context,
      MaterialPageRoute(
        builder: (context) => OwnerMotelFormPage(
          isEditing: isEditing,
          motel: motelToEdit,
          ownerId: _currentOwnerId, 
        ),
      ),
    );

    if (result != null) {
      setState(() {
        if (isEditing) {
          final index = _motels.indexWhere((m) => m.id == result.id);
          if (index != -1) {
            _motels[index] = result;
          }
        } else {
          if (result.ownerId == _currentOwnerId) {
            _motels.insert(0, result);
          }
        }
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isEditing ? 'Motel actualizado con éxito' : 'Motel creado y asignado con éxito')),
        );
      }
    }
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
    final currentOwnerName = widget.initialOwnerName ??
        _owners
            .firstWhere(
              (o) => o.id == _currentOwnerId,
              orElse: () => Owner(
                id: _currentOwnerId,
                fullName: 'Propietario',
                documentType: DocumentType.citizenshipCard,
                documentNumber: '',
                email: '',
                phone: '',
              ),
            )
            .fullName;

    final filteredMotels = _motels.where((motel) {
      final nameLower = motel.name.toLowerCase();
      final idLower = motel.id.toLowerCase();
      final query = _searchQuery.toLowerCase();
      return nameLower.contains(query) || idLower.contains(query);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          currentOwnerName,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        leadingWidth: 68,
        // Reemplazo: botón de flecha atrás para regresar a owner_page.dart
        leading: Padding(
          padding: const EdgeInsets.only(left: AppSpacing.s4),
          child: AppIconButton(
            icon: Icons.arrow_back,
            tooltip: 'Volver a Propietarios',
            onPressed: () => Navigator.pop(context),
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
                    'Vista de Propietario: $currentOwnerName',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
            // Opción de notificaciones movida aquí
            _MenuTile(
              icon: Icons.notifications_outlined, 
              title: 'Notificaciones', 
              onTap: () {
                Navigator.pop(context);
              },
            ),
            _MenuTile(icon: Icons.security_outlined, title: 'Seguridad y Roles', onTap: () {}),
            _MenuTile(icon: Icons.analytics_outlined, title: 'Reportes Globales', onTap: () {}),
            _MenuTile(
              icon: Icons.support_agent_outlined, 
              title: 'PQRS de Usuarios', 
              onTap: () {
                Navigator.pop(context); 
              },
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
                  label: Text(currentOwnerName.split(' ').first, style: const TextStyle(fontSize: 12)),
                  backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s3),
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
                      ? const Center(child: Text('No se encontraron establecimientos registrados para este propietario.'))
                      : ListView.separated(
                          itemCount: filteredMotels.length,
                          separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.s3),
                          itemBuilder: (context, index) {
                            final motel = filteredMotels[index];
                            return _AdminMotelCard(
                              motel: motel,
                              activeReservations: 3, 
                              onToggleStatus: () => _toggleMotelStatus(index),
                              onEdit: () => _showMotelFormModal(motelToEdit: motel), 
                              onManage: () {
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showMotelFormModal(),
        icon: const Icon(Icons.add),
        label: const Text('Agregar'),
      ),
    );
  }
}

class _AdminMotelCard extends StatelessWidget {
  const _AdminMotelCard({
    required this.motel,
    required this.activeReservations,
    required this.onToggleStatus,
    required this.onEdit,
    required this.onManage,
  });

  final Motel motel;
  final int activeReservations;
  final VoidCallback onToggleStatus;
  final VoidCallback onEdit;
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
                    fontWeight: FontWeight.bold,
                    decoration: isActive ? null : TextDecoration.lineThrough,
                  ),
                ),
                const SizedBox(height: AppSpacing.s1),
                Text(
                  '$activeReservations reservas • Dueño ID: ${motel.ownerId.substring(0, 8)}...',
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
                tooltip: 'Editar establecimiento',
                onPressed: onEdit,
              ),
              IconButton(
                icon: Icon(isActive ? Icons.block : Icons.check_circle_outline),
                tooltip: isActive ? 'Bloquear establecimiento' : 'Desbloquear establecimiento',
                color: isActive ? Colors.redAccent : Colors.green,
                onPressed: () => _showConfirmDialog(context), 
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                tooltip: 'Opciones de administración',
                onSelected: (String value) {
                  if (value == 'gestion') {
                    onManage();
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
                    value: 'gestion',
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