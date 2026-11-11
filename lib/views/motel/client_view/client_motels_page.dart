import 'package:flutter/material.dart';
import '../../../core/design_system/design_system.dart';
import '../../../widgets/notification/unread_notification_button.dart';
import './../../../models/motel/motel_model.dart';
import '../../../controllers/motel/motel_controller.dart';
import '../../../database/repository/motel/motel_repository.dart';
import './../../../routes/routes.dart';
import '../../login/logout_navigation.dart';
import '../../booking/client_view/client_reservations_page.dart';
import '../../pqrs/client_view/pqrs_page.dart';
import '../../notification/client_view/client_notification_view.dart';
import '../../../controllers/client/client_controller.dart';

class ClientMotelsPage extends StatefulWidget {
  const ClientMotelsPage({super.key, this.controller});

  final MotelController? controller;

  @override
  State<ClientMotelsPage> createState() => _ClientMotelsPageState();
}

class _ClientMotelsPageState extends State<ClientMotelsPage> {
  final TextEditingController _searchController = TextEditingController();
  int _selectedIndex = 0;
  final Set<int> _visitedTabs = {0};

  late final MotelController _motelController;
  late Future<List<Motel>> _motelsFuture;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _motelController = widget.controller ?? MotelController.persistent();
    _motelsFuture = _motelController.getRecommendedMotels();
  }

  Future<void> _refreshMotels() async {
    if (_isRefreshing) return;
    final request = _motelController.getRecommendedMotels();
    setState(() {
      _isRefreshing = true;
      _motelsFuture = request;
    });
    try {
      await request;
    } catch (_) {
      // FutureBuilder presents the error and its retry action. Never replace
      // a failed request with demo data or an empty successful response.
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildMotelsContent(),
          _visitedTabs.contains(1)
              ? const ClientReservationsPage()
              : const SizedBox.shrink(),
          _visitedTabs.contains(2)
              ? const ClientPqrsPage()
              : const SizedBox.shrink(),
        ],
      ),
      bottomNavigationBar: AppNavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
            _visitedTabs.add(index);
          });
          if (index == 0) _refreshMotels();
        },
        destinations: const [
          AppNavigationDestination(
            icon: Icons.home_outlined,
            selectedIcon: Icons.home,
            label: 'Moteles',
          ),
          AppNavigationDestination(
            icon: Icons.event_note_outlined,
            selectedIcon: Icons.event_note,
            label: 'Mis Reservas',
          ),
          AppNavigationDestination(
            icon: Icons.support_agent_outlined,
            selectedIcon: Icons.support_agent,
            label: 'Mis PQRS',
          ),
        ],
      ),
    );
  }

  Future<void> _logout() async {
    await logoutAndGoToLogin(context);
  }

  Widget _buildMotelsContent() {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Lista Moteles'),
        leadingWidth: 68,
        leading: Padding(
          padding: const EdgeInsets.only(left: AppSpacing.s4),
          child: UnreadNotificationButton(
            recipientRole: 'client',
            onPressed: () => Navigator.push<void>(
              context,
              MaterialPageRoute(
                builder: (context) => const ClientNotificationView(),
              ),
            ),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.s4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppIconButton(
                  icon: Icons.refresh,
                  tooltip: 'Actualizar moteles',
                  onPressed: _isRefreshing ? null : _refreshMotels,
                ),
                AppIconButton(
                  icon: Icons.person_outline,
                  tooltip: 'Perfil',
                  onPressed: () {
                    ClientController.instance.loadProfileData();
                    Navigator.pushNamed(context, AppRoutes.clientProfile);
                  },
                ),
                const SizedBox(width: AppSpacing.s2),
                AppIconButton(
                  icon: Icons.logout,
                  tooltip: 'Cerrar sesión',
                  onPressed: _logout,
                ),
              ],
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: AppSpacing.s2),
            AppSearchField(
              label: 'Buscar moteles o zonas...',
              controller: _searchController,
              onChanged: (value) {
                setState(() {});
              },
              onClear: () {
                _searchController.clear();
                setState(() {});
              },
            ),
            const SizedBox(height: AppSpacing.s5),
            Text(
              'Recomendados para ti',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.s3),
            Expanded(
              child: FutureBuilder<List<Motel>>(
                future: _motelsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return _refreshableState(
                      AppErrorState(
                        message: snapshot.error is MotelRepositoryException
                            ? (snapshot.error! as MotelRepositoryException)
                                  .message
                            : 'No se pudieron cargar los moteles. Inténtalo nuevamente.',
                        onRetry: _refreshMotels,
                      ),
                    );
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return _refreshableState(
                      AppEmptyState(
                        icon: Icons.hotel_outlined,
                        title: 'Sin moteles disponibles',
                        message: 'No hay moteles disponibles en este momento.',
                        actionLabel: 'Actualizar',
                        onAction: _refreshMotels,
                      ),
                    );
                  }

                  final allMotels = snapshot.data!;
                  final query = _searchController.text.toLowerCase();

                  final filteredMotels = allMotels.where((motel) {
                    final matchName = motel.name.toLowerCase().contains(query);
                    final matchLocation = motel.address.toLowerCase().contains(
                      query,
                    );
                    final matchZone = (motel.generalLocation ?? '')
                        .toLowerCase()
                        .contains(query);
                    return motel.isAvailable &&
                        (matchName || matchLocation || matchZone);
                  }).toList();

                  if (filteredMotels.isEmpty) {
                    return _refreshableState(
                      const AppEmptyState(
                        icon: Icons.search_off_outlined,
                        title: 'Sin resultados',
                        message:
                            'No se encontraron resultados para tu búsqueda.',
                      ),
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: _refreshMotels,
                    child: ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: filteredMotels.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: AppSpacing.s4),
                      itemBuilder: (context, index) {
                        final motel = filteredMotels[index];
                        return _ClientMotelCard(
                          name: motel.name,
                          location: motel.address,
                          isAvailable: motel.isAvailable,
                          onTap: () async {
                            await Navigator.pushNamed(
                              context,
                              AppRoutes.clientMotelDetail,
                              arguments: motel,
                            );
                            if (mounted) await _refreshMotels();
                          },
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _refreshableState(Widget child) => RefreshIndicator(
    onRefresh: _refreshMotels,
    child: ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [child],
    ),
  );
}

class _ClientMotelCard extends StatelessWidget {
  const _ClientMotelCard({
    required this.name,
    required this.location,
    required this.isAvailable,
    required this.onTap,
  });

  final String name;
  final String location;
  final bool isAvailable;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 120,
            width: double.infinity,
            decoration: BoxDecoration(
              color: context.appColors.mediaFallback,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(
              Icons.image_outlined,
              size: 40,
              color: context.appColors.textDisabled,
            ),
          ),
          const SizedBox(height: AppSpacing.s3),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  name,
                  style: Theme.of(context).textTheme.headlineSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              StatusBadge(
                status: isAvailable ? AppStatus.available : AppStatus.occupied,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s1),
          Text(
            location,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: context.appColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.s3),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              AppButton(
                label: 'Ver más',
                size: AppButtonSize.medium,
                expanded: false,
                onPressed: onTap,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
