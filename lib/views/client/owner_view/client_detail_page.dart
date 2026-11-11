import 'package:flutter/material.dart';
import '../../../core/design_system/design_system.dart';
import '../../../models/client/client_model.dart';
import '../../booking/owner_view/owner_reservations_page.dart';

class ClientDetailPage extends StatelessWidget {
  const ClientDetailPage({
    super.key,
    required this.client,
  });

  final ClientModel client;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle del Cliente'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                    child: Text(
                      client.name.isNotEmpty ? client.name[0].toUpperCase() : 'C',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s3),
                  Text(
                    client.name,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: AppSpacing.s1),
                  Chip(
                    label: const Text('Cliente', style: TextStyle(fontSize: 12)),
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.s5),
            Text(
              'Información personal',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: AppSpacing.s3),
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.s3),
              child: Column(
                children: [
                  _DetailTile(
                    icon: Icons.person_outline,
                    label: 'Nombre completo',
                    value: client.name,
                  ),
                  const Divider(),
                  _DetailTile(
                    icon: Icons.email_outlined,
                    label: 'Correo electrónico',
                    value: client.email,
                  ),
                  const Divider(),
                  _DetailTile(
                    icon: Icons.phone_outlined,
                    label: 'Teléfono',
                    value: '${client.countryCode} ${client.phone}',
                  ),
                  if (client.uid != null) ...[
                    const Divider(),
                    _DetailTile(
                      icon: Icons.badge_outlined,
                      label: 'ID de Usuario (UID)',
                      value: client.uid!,
                    ),
                  ],
                ],
              ),
            ),
            // Reservations are linked to the client by their Firebase uid
            // (`guestId`), so the history needs it.
            if (client.uid != null) ...[
              const SizedBox(height: AppSpacing.s5),
              AppButton(
                label: 'Ver historial de reservas',
                icon: Icons.history,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => OwnerReservationsPage(
                      clientId: client.uid,
                      clientName: client.name,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DetailTile extends StatelessWidget {
  const _DetailTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s2),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: AppSpacing.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.appColors.textSecondary,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}