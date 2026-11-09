import 'package:flutter/material.dart';
import '../../../core/design_system/design_system.dart';
import '../../../controllers/client/client_controller.dart';
import '../../../models/client/client_model.dart';
import 'client_detail_page.dart';

class ClientListPage extends StatefulWidget {
  const ClientListPage({super.key});

  @override
  State<ClientListPage> createState() => _ClientListPageState();
}

class _ClientListPageState extends State<ClientListPage> {
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    // Carga los usuarios con role == 'client' desde Firestore
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ClientController.instance.loadAllClients();
    });
  }

  void _confirmUnlink(BuildContext context, ClientModel client) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¿Desvincular cliente?'),
        content: Text(
          '¿Estás seguro de que deseas desvincular a "${client.name}" de la vista?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () {
              Navigator.pop(dialogContext);
              ClientController.instance.unlink(client);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Cliente "${client.name}" desvinculado.')),
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
      appBar: AppBar(
        title: const Text('Lista de Clientes'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: AppSpacing.s4),
            AppSearchField(
              label: 'Buscar cliente por nombre, correo o teléfono...',
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
            const SizedBox(height: AppSpacing.s3),
            Expanded(
              child: ListenableBuilder(
                listenable: ClientController.instance,
                builder: (context, _) {
                  final controller = ClientController.instance;

                  if (controller.isLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (controller.errorMessage != null) {
                    return Center(
                      child: Text(
                        controller.errorMessage!,
                        style: TextStyle(color: Theme.of(context).colorScheme.error),
                      ),
                    );
                  }

                  final clients = controller.search(_searchQuery);

                  if (clients.isEmpty) {
                    return const Center(
                      child: Text('No se encontraron clientes registrados.'),
                    );
                  }

                  return ListView.separated(
                    itemCount: clients.length,
                    separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.s3),
                    itemBuilder: (context, index) {
                      final client = clients[index];
                      return _ClientCard(
                        client: client,
                        onUnlink: () => _confirmUnlink(context, client),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ClientDetailPage(client: client),
                            ),
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

class _ClientCard extends StatelessWidget {
  const _ClientCard({
    required this.client,
    required this.onUnlink,
    required this.onTap,
  });

  final ClientModel client;
  final VoidCallback onUnlink;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.s3),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
          child: Text(
            client.name.isNotEmpty ? client.name[0].toUpperCase() : 'C',
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          client.name,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(client.email, style: Theme.of(context).textTheme.bodySmall),
            Text('${client.countryCode} ${client.phone}', style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.link_off, color: Colors.redAccent),
          tooltip: 'Desvincular cliente',
          onPressed: onUnlink,
        ),
        onTap: onTap,
      ),
    );
  }
}