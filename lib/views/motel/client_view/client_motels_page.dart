import 'package:flutter/material.dart';
import '../../../core/design_system/design_system.dart';
import './../../../models/motel/motel_model.dart';
import './../../../controllers/motel/client_controller/client_motel_controller.dart';
import './../../../routes/routes.dart';
import '../../pqrs/client_view/pqrs_page.dart';

class ClientMotelsPage extends StatefulWidget {
  const ClientMotelsPage({super.key});

  @override
  State<ClientMotelsPage> createState() => _ClientMotelsPageState();
}

class _ClientMotelsPageState extends State<ClientMotelsPage> {
  final TextEditingController _searchController = TextEditingController();
  int _selectedIndex = 0;
  
  final ClientMotelController _motelController = ClientMotelController();
  late Future<List<Motel>> _motelsFuture;

  @override
  void initState() {
    super.initState();
    _motelsFuture = _motelController.getRecommendedMotels();
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

          
          const ClientPqrsPage(),
        ],
      ),
      bottomNavigationBar: AppNavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
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

  Widget _buildMotelsContent() {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Lista Moteles'),
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
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.s4),
            child: AppIconButton(
              icon: Icons.person_outline,
              tooltip: 'Perfil',
              onPressed: () {},
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
              label: 'Buscar moteles, zonas o servicios...',
              controller: _searchController,
              onChanged: (value) {},
              onClear: () {
                _searchController.clear();
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
                    return Center(child: Text('Error al cargar: ${snapshot.error}'));
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(child: Text('No hay moteles disponibles en este momento.'));
                  }

                  final motels = snapshot.data!;
                  return ListView.separated(
                    itemCount: motels.length,
                    separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.s4),
                    itemBuilder: (context, index) {
                      final motel = motels[index];
                      return _ClientMotelCard(
                        name: motel.name,
                        location: motel.address,
                        price: '\$${motel.basePrice.toStringAsFixed(0)} / 4 horas',
                        isAvailable: motel.isAvailable,
                        onTap: () {
                          Navigator.pushNamed(
                            context, 
                            AppRoutes.clientMotelDetail, 
                            arguments: motel,
                          );
                        },
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

class _ClientMotelCard extends StatelessWidget {
  const _ClientMotelCard({
    required this.name,
    required this.location,
    required this.price,
    required this.isAvailable,
    required this.onTap,
  });

  final String name;
  final String location;
  final String price;
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
              Text(
                price,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
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