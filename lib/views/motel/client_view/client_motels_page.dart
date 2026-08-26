import 'package:flutter/material.dart';
// Ajusta la ruta de importación según tu árbol de directorios
import '../../../core/design_system/design_system.dart';
import 'client_motel_detail_page.dart';

class ClientMotelsPage extends StatefulWidget {
  const ClientMotelsPage({super.key});

  @override
  State<ClientMotelsPage> createState() => _ClientMotelsPageState();
}

class _ClientMotelsPageState extends State<ClientMotelsPage> {
  final TextEditingController _searchController = TextEditingController();
  int _selectedIndex = 0; // Para el AppNavigationBar

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Lista Moteles'),
        // Ampliamos el espacio del leading para que el botón mantenga su forma circular
        leadingWidth: 68, 
        leading: Padding(
          padding: const EdgeInsets.only(left: AppSpacing.s4), // AppSpacing.s4 = 16.0
          child: AppIconButton(
            icon: Icons.notifications_none_outlined,
            tooltip: 'Notificaciones',
            onPressed: () {
              // TODO: Navegar a notificaciones
            },
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.s4), // Mismo padding que la izquierda
            child: AppIconButton(
              icon: Icons.person_outline,
              tooltip: 'Perfil',
              onPressed: () {
                // TODO: Navegar al perfil del cliente
              },
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
            // Barra de búsqueda del Design System
            AppSearchField(
              label: 'Buscar moteles, zonas o servicios...',
              controller: _searchController,
              onChanged: (value) {
                // Aquí se conectará el controlador para filtrar
              },
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
              // Este ListView se alimentará después del Modelo/Controlador
              child: ListView.separated(
                itemCount: 5,
                separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.s4),
                itemBuilder: (context, index) {
                  return _ClientMotelCard(
                    name: 'Motel Paraíso Élite',
                    location: 'Rionegro, Antioquia',
                    price: '\$80.000 / 4 horas',
                    isAvailable: index % 2 == 0, // Simulando disponibilidad
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ClientMotelDetailPage(
                            motelName: "Motel Machuco",
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      // Navegación inferior con las 3 secciones solicitadas
      bottomNavigationBar: AppNavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
          // TODO: Manejar la navegación entre las vistas de Reservas y PQRS
        },
        destinations: const [
          AppNavigationDestination(
            icon: Icons.home_outlined,
            selectedIcon: Icons.home,
            label: 'Moteles', // Izquierda
          ),
          AppNavigationDestination(
            icon: Icons.event_note_outlined,
            selectedIcon: Icons.event_note,
            label: 'Mis Reservas', // Centro
          ),
          AppNavigationDestination(
            icon: Icons.support_agent_outlined,
            selectedIcon: Icons.support_agent,
            label: 'Mis PQRS', // Derecha
          ),
        ],
      ),
    );
  }
}

// Sub-componente privado para la tarjeta del motel (Sin cambios mayores, listo para usar)
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
          // Imagen simulada (Placeholder)
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
                label: 'Ver más', // Según tu boceto "Ver" o "Reservar", este botón lleva al detalle
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