import 'package:flutter/material.dart';
import 'package:machuco/controllers/client/client_controller.dart';
import 'package:machuco/core/design_system/design_system.dart';
import 'package:machuco/models/client/client.dart';
import 'package:machuco/routes/routes.dart';

class ClientListPage extends StatefulWidget {
  const ClientListPage({super.key});

  @override
  State<ClientListPage> createState() => _ClientListPageState();
}

class _ClientListPageState extends State<ClientListPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _confirmUnlink(BuildContext context, Client client) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Desvincular cliente'),
        content: Text('¿Estás seguro de que deseas desvincular a ${client.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () {
              ClientController.instance.unlink(client);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${client.name} ha sido desvinculado.')),
              );
            },
            child: const Text('Desvincular'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mis Clientes')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.screen),
              child: AppTextField(
                label: 'Buscar clientes',
                controller: _searchController,
                hint: 'Nombre o correo...',
                prefixIcon: const Icon(Icons.search),
              ),
            ),
            Expanded(
              child: ListenableBuilder(
                listenable: ClientController.instance,
                builder: (context, _) {
                  // Consumimos la instancia Singleton
                  final clients = ClientController.instance.search(_searchQuery);

                  if (clients.isEmpty) {
                    return const Center(
                      child: Text('No se encontraron clientes.'),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.screen,
                      vertical: AppSpacing.s2,
                    ),
                    itemCount: clients.length,
                    separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.s3),
                    itemBuilder: (context, index) {
                      final client = clients[index];
                      return _ClientCard(
                        client: client,
                        onUnlink: () => _confirmUnlink(context, client),
                        onTap: () {
                          // Navegación hipotética al detalle del cliente
                          // Navigator.pushNamed(context, AppRoutes.clientDetail, arguments: client.id);
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

class _ClientCard extends StatelessWidget {
  const _ClientCard({
    required this.client,
    required this.onUnlink,
    required this.onTap,
  });

  final Client client;
  final VoidCallback onUnlink;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s4),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                alignment: Alignment.center,
                child: Text(
                  client.initials,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.s4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      client.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.s1),
                    Text(
                      client.email,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.appColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.link_off,
                  color: Theme.of(context).colorScheme.error,
                ),
                onPressed: onUnlink,
                tooltip: 'Desvincular cliente',
              ),
            ],
          ),
        ),
      ),
    );
  }
}