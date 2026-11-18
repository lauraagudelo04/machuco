import 'package:flutter/material.dart';
import '../../../controllers/motel/motel_controller.dart';
import '../../../controllers/owner_management/owner_controller.dart';
import '../../../core/design_system/design_system.dart';
import '../../../models/motel/motel_model.dart';
import '../../../models/owner_management/owner.dart';
import '../../../routes/routes.dart';
import '../../booking/system_admin_view/admin_motel_reservations_list_page.dart';
import '../../notification/system_admin_view/system_admin_notification_view.dart';
import '../../payment/owner_view/owner_payment_page.dart';
import '../../pqrs/system_admin_view/pqrs_page.dart';
import 'admin_motel_form_page.dart';

/// Administración de moteles del administrador del sistema.
///
/// Muestra los moteles de toda la plataforma (Firebase SQL Connect, con caché
/// local si no hay red) y permite filtrarlos por propietario. Si se abre desde
/// un propietario ([initialOwnerId]) arranca filtrada por él. Crear, editar y
/// bloquear/desbloquear se guardan en el servidor antes de cambiar la lista.
class AdminMotelsPage extends StatefulWidget {
  const AdminMotelsPage({
    super.key,
    this.initialOwnerId,
    this.initialOwnerName,
    this.motelController,
    this.ownerController,
  });

  final String? initialOwnerId;
  final String? initialOwnerName;

  /// Inyectables para pruebas; por defecto se usan los persistentes.
  final MotelController? motelController;
  final OwnerController? ownerController;

  @override
  State<AdminMotelsPage> createState() => _AdminMotelsPageState();
}

class _AdminMotelsPageState extends State<AdminMotelsPage> {
  int _selectedIndex = 0;

  late final MotelController _motelController =
      widget.motelController ?? MotelController.persistent();
  late final OwnerController _ownerController =
      widget.ownerController ?? OwnerController.instance;

  List<Motel> _motels = [];
  List<Owner> _owners = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _searchQuery = '';

  /// Propietario por el que se filtra; `null` muestra todos los moteles.
  String? _selectedOwnerId;

  /// Moteles con una operación en curso, para no repetirla.
  final Set<String> _busyMotelIds = {};

  @override
  void initState() {
    super.initState();
    final initialOwnerId = widget.initialOwnerId;
    _selectedOwnerId = initialOwnerId == null || initialOwnerId.isEmpty
        ? null
        : initialOwnerId;
    _loadOwnersAndMotels();
  }

  Future<void> _loadOwnersAndMotels() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // Los nombres de los propietarios son un complemento: si fallan, el
    // listado de moteles se muestra igual.
    try {
      await _ownerController.init();
      _owners = List.of(_ownerController.owners);
    } catch (_) {
      _owners = [];
    }

    try {
      final motels = await _motelController.getAllMotels();
      if (!mounted) return;
      setState(() {
        _motels = List.of(motels);
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.toString();
        _isLoading = false;
      });
    }
  }

  Map<String, String> get _ownerNamesById {
    final names = <String, String>{
      for (final owner in _owners) owner.id: owner.fullName,
    };
    // Cubre propietarios recién registrados que aún no están en el catálogo.
    final initialOwnerId = widget.initialOwnerId;
    final initialOwnerName = widget.initialOwnerName;
    if (initialOwnerId != null && initialOwnerName != null) {
      names.putIfAbsent(initialOwnerId, () => initialOwnerName);
    }
    return names;
  }

  List<Motel> get _visibleMotels {
    final query = _searchQuery.trim().toLowerCase();
    return _motels.where((motel) {
      if (_selectedOwnerId != null && motel.ownerId != _selectedOwnerId) {
        return false;
      }
      if (query.isEmpty) return true;
      return motel.name.toLowerCase().contains(query) ||
          motel.id.toLowerCase().contains(query) ||
          motel.nit.toLowerCase().contains(query);
    }).toList();
  }

  void _replaceMotel(Motel motel) {
    final index = _motels.indexWhere((m) => m.id == motel.id);
    if (index == -1) {
      _motels.insert(0, motel);
    } else {
      _motels[index] = motel;
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _toggleMotelStatus(Motel motel) async {
    if (_busyMotelIds.contains(motel.id)) return;
    setState(() => _busyMotelIds.add(motel.id));
    try {
      final updated = await _motelController.adminToggleMotelStatus(motel);
      if (!mounted) return;
      setState(() {
        _replaceMotel(
          updated ?? motel.copyWith(isAvailable: !motel.isAvailable),
        );
      });
      _showMessage(
        motel.isAvailable
            ? '"${motel.name}" quedó bloqueado'
            : '"${motel.name}" quedó desbloqueado',
      );
    } catch (error) {
      _showMessage(error.toString());
    } finally {
      if (mounted) setState(() => _busyMotelIds.remove(motel.id));
    }
  }

  Future<void> _openMotelForm({Motel? motelToEdit}) async {
    final isEditing = motelToEdit != null;
    final saved = await Navigator.push<Motel>(
      context,
      MaterialPageRoute(
        builder: (context) => AdminMotelFormPage(
          motelController: _motelController,
          motel: motelToEdit,
          ownerId: isEditing ? null : _selectedOwnerId,
          owners: _owners,
        ),
      ),
    );
    if (saved == null || !mounted) return;

    setState(() => _replaceMotel(saved));
    _showMessage(
      isEditing
          ? 'Motel actualizado con éxito'
          : 'Motel creado y asignado con éxito',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildMotelsContent(),
          AdminMotelReservationsListPage(ownerId: _selectedOwnerId ?? ''),
          const SystemAdminNotificationView(),
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
            icon: Icons.notifications_outlined,
            selectedIcon: Icons.notifications,
            label: 'Notificaciones',
          ),
        ],
      ),
    );
  }

  Widget _buildMotelsContent() {
    final ownerNamesById = _ownerNamesById;
    final selectedOwnerName = _selectedOwnerId == null
        ? null
        : ownerNamesById[_selectedOwnerId] ?? 'Propietario';
    final title = selectedOwnerName ?? 'Todos los moteles';
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          title,
          style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        leadingWidth: 68,
        leading: Navigator.canPop(context)
            ? Padding(
                padding: const EdgeInsets.only(left: AppSpacing.s4),
                child: AppIconButton(
                  icon: Icons.arrow_back,
                  tooltip: 'Volver a Propietarios',
                  onPressed: () => Navigator.pop(context),
                ),
              )
            : null,
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
              decoration: BoxDecoration(color: colorScheme.primary),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'Menú Administrador',
                    style: textTheme.headlineSmall?.copyWith(
                      color: colorScheme.onPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s1),
                  Text(
                    selectedOwnerName == null
                        ? 'Todos los propietarios'
                        : 'Vista de Propietario: $selectedOwnerName',
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onPrimary,
                    ),
                  ),
                ],
              ),
            ),
            _MenuTile(
              icon: Icons.star_outline,
              title: 'Reseñas',
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, AppRoutes.adminReviews);
              },
            ),
            _MenuTile(
              icon: Icons.support_agent_outlined,
              title: 'PQRS',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SystemAdminPqrsPage(),
                  ),
                );
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
            Text('Gestión de Establecimientos', style: textTheme.headlineSmall),
            const SizedBox(height: AppSpacing.s3),
            _OwnerFilter(
              owners: _owners,
              ownerNamesById: ownerNamesById,
              selectedOwnerId: _selectedOwnerId,
              onChanged: (ownerId) =>
                  setState(() => _selectedOwnerId = ownerId),
            ),
            const SizedBox(height: AppSpacing.s3),
            AppSearchField(
              label: 'Buscar moteles por nombre, NIT o ID...',
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
            const SizedBox(height: AppSpacing.s3),
            Expanded(child: _buildMotelList(ownerNamesById)),
          ],
        ),
      ),
      floatingActionButton: _errorMessage == null && !_isLoading
          ? FloatingActionButton.extended(
              onPressed: () => _openMotelForm(),
              icon: const Icon(Icons.add),
              label: const Text('Agregar'),
            )
          : null,
    );
  }

  Widget _buildMotelList(Map<String, String> ownerNamesById) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    final errorMessage = _errorMessage;
    if (errorMessage != null) {
      return AppErrorState(
        message: errorMessage,
        onRetry: _loadOwnersAndMotels,
      );
    }

    final motels = _visibleMotels;
    if (motels.isEmpty) {
      return AppEmptyState(
        icon: Icons.domain_disabled_outlined,
        title: 'Sin establecimientos',
        message: _selectedOwnerId == null
            ? 'No se encontraron moteles registrados.'
            : 'No se encontraron establecimientos registrados para este propietario.',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadOwnersAndMotels,
      child: ListView.separated(
        padding: const EdgeInsets.only(bottom: AppSpacing.s12 + AppSpacing.s8),
        itemCount: motels.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.s3),
        itemBuilder: (context, index) {
          final motel = motels[index];
          return _AdminMotelCard(
            motel: motel,
            ownerName: ownerNamesById[motel.ownerId] ?? 'Propietario',
            isBusy: _busyMotelIds.contains(motel.id),
            onToggleStatus: () => _toggleMotelStatus(motel),
            onEdit: () => _openMotelForm(motelToEdit: motel),
          );
        },
      ),
    );
  }
}

/// Selector de propietario: "Todos los propietarios" o uno en particular.
class _OwnerFilter extends StatelessWidget {
  const _OwnerFilter({
    required this.owners,
    required this.ownerNamesById,
    required this.selectedOwnerId,
    required this.onChanged,
  });

  final List<Owner> owners;
  final Map<String, String> ownerNamesById;
  final String? selectedOwnerId;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    // Incluye al propietario inicial aunque no esté en el catálogo cargado.
    final ids = <String>{
      for (final owner in owners) owner.id,
      ?selectedOwnerId,
    };

    return DropdownButtonFormField<String?>(
      key: ValueKey(selectedOwnerId),
      initialValue: selectedOwnerId,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'Propietario',
        prefixIcon: const Icon(Icons.person_outline),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s4,
          vertical: AppSpacing.s3,
        ),
      ),
      items: [
        const DropdownMenuItem<String?>(
          value: null,
          child: Text('Todos los propietarios'),
        ),
        for (final id in ids)
          DropdownMenuItem<String?>(
            value: id,
            child: Text(
              ownerNamesById[id] ?? 'Propietario',
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: onChanged,
    );
  }
}

class _AdminMotelCard extends StatelessWidget {
  const _AdminMotelCard({
    required this.motel,
    required this.ownerName,
    required this.isBusy,
    required this.onToggleStatus,
    required this.onEdit,
  });

  final Motel motel;
  final String ownerName;
  final bool isBusy;
  final VoidCallback onToggleStatus;
  final VoidCallback onEdit;

  Future<void> _showConfirmDialog(BuildContext context) async {
    final isActive = motel.isAvailable;
    final colorScheme = Theme.of(context).colorScheme;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            isActive ? '¿Bloquear motel desde Admin?' : '¿Desbloquear motel?',
          ),
          content: Text(
            isActive
                ? 'Al bloquear "${motel.name}", se restringirá el acceso general en la plataforma de manera administrativa.'
                : 'Al desbloquear "${motel.name}", el establecimiento recuperará su visibilidad pública.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              style: isActive
                  ? FilledButton.styleFrom(
                      backgroundColor: colorScheme.error,
                      foregroundColor: colorScheme.onError,
                    )
                  : null,
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(isActive ? 'Sí, bloquear' : 'Sí, desbloquear'),
            ),
          ],
        );
      },
    );
    if (confirmed == true) onToggleStatus();
  }

  @override
  Widget build(BuildContext context) {
    final isActive = motel.isAvailable;
    final colorScheme = Theme.of(context).colorScheme;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.s3),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isActive
                  ? context.appColors.elevated
                  : context.appColors.mediaFallback,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(
              Icons.domain,
              color: isActive
                  ? colorScheme.primary
                  : context.appColors.textDisabled,
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
                  'NIT ${motel.nit} • Dueño: $ownerName',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.appColors.textSecondary,
                  ),
                ),
                if (!isActive)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.s1),
                    child: Text(
                      'Bloqueado',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colorScheme.error,
                      ),
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
                onPressed: isBusy ? null : onEdit,
              ),
              if (isBusy)
                const Padding(
                  padding: EdgeInsets.all(AppSpacing.s3),
                  child: SizedBox(
                    width: AppSpacing.s6,
                    height: AppSpacing.s6,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else
                IconButton(
                  icon: Icon(
                    isActive ? Icons.block : Icons.check_circle_outline,
                  ),
                  tooltip: isActive
                      ? 'Bloquear establecimiento'
                      : 'Desbloquear establecimiento',
                  color: isActive ? colorScheme.error : AppColors.available,
                  onPressed: () => _showConfirmDialog(context),
                ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                tooltip: 'Opciones de administración',
                onSelected: (value) => _openOption(context, value),
                itemBuilder: (context) => const [
                  PopupMenuItem<String>(
                    value: 'habitaciones',
                    child: _OptionLabel(
                      icon: Icons.bed_outlined,
                      label: 'Habitaciones',
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'productos',
                    child: _OptionLabel(
                      icon: Icons.inventory_2_outlined,
                      label: 'Productos',
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'servicios',
                    child: _OptionLabel(
                      icon: Icons.room_preferences_outlined,
                      label: 'Servicios adicionales',
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'finanzas',
                    child: _OptionLabel(
                      icon: Icons.attach_money_outlined,
                      label: 'Finanzas',
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

  void _openOption(BuildContext context, String value) {
    switch (value) {
      case 'habitaciones':
        Navigator.pushNamed(context, AppRoutes.adminRooms, arguments: motel);
      case 'productos':
        Navigator.pushNamed(
          context,
          AppRoutes.ownerProducts,
          arguments: motel.id,
        );
      case 'servicios':
        Navigator.pushNamed(
          context,
          AppRoutes.adminAdditionalServices,
          arguments: motel.id,
        );
      case 'finanzas':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                OwnerPaymentsPage(motelId: motel.id, motelName: motel.name),
          ),
        );
    }
  }
}

class _OptionLabel extends StatelessWidget {
  const _OptionLabel({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: AppSpacing.s2),
        Text(label),
      ],
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

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
