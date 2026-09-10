import 'package:flutter/material.dart';
import 'package:machuco/controllers/client/client_controller.dart';
import 'package:machuco/core/design_system/components/app_button.dart';
import 'package:machuco/core/design_system/components/app_card.dart';
import 'package:machuco/core/design_system/components/app_icon_button.dart';
import 'package:machuco/core/design_system/components/app_text_field.dart';
import 'package:machuco/core/design_system/tokens/app_colors.dart';
import 'package:machuco/core/design_system/tokens/app_radius.dart';
import 'package:machuco/core/design_system/tokens/app_spacing.dart';
import 'package:machuco/core/design_system/theme/app_theme_extensions.dart';
import 'package:machuco/models/client/client.dart';
import 'client_detail_page.dart';

class ClientPage extends StatefulWidget {
  const ClientPage({super.key});

  @override
  State<ClientPage> createState() => _ClientPageState();
}

class _ClientPageState extends State<ClientPage> {
  final TextEditingController _searchController = TextEditingController();

  List<Client> get _filteredClients =>
      ClientController.search(_searchController.text);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openClientDetail(Client client) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => ClientDetailPage(client: client)));
  }

  Future<void> _showUnlinkDialog(Client client) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _UnlinkClientDialog(client: client),
    );
    if (confirmed != true || !mounted) return;

    setState(() => ClientController.unlink(client));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text('${client.name} fue desasociado del motel')),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Clientes')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.screen),
          children: [
            _buildHeader(context),
            const SizedBox(height: AppSpacing.s5),
            AppTextField(
              label: 'Buscar clientes',
              controller: _searchController,
              hint: 'Nombre o correo',
              prefixIcon: const Icon(Icons.search),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: AppSpacing.s6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Clientes asociados',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                Text(
                  '${_filteredClients.length} de ${ClientController.clients.length}',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: context.appColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s3),
            if (_filteredClients.isEmpty)
              _buildEmptyState(context)
            else
              ..._filteredClients.map(
                (client) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.s3),
                  child: _ClientCard(
                    client: client,
                    onTap: () => _openClientDetail(client),
                    onUnlink: () => _showUnlinkDialog(client),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Administra tus clientes',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: AppSpacing.s2),
        Text(
          'Consulta los clientes asociados a tus moteles y desasócialos cuando lo necesites.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: context.appColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s6),
        child: Column(
          children: [
            Icon(
              Icons.person_search_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: AppSpacing.s3),
            Text(
              'No encontramos clientes',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.s2),
            Text(
              ClientController.clients.isEmpty
                  ? 'Aún no tienes clientes asociados a tus moteles.'
                  : 'Prueba con otro término de búsqueda.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: context.appColors.textSecondary,
              ),
              textAlign: TextAlign.center,
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
    required this.onTap,
    required this.onUnlink,
  });

  final Client client;
  final VoidCallback onTap;
  final VoidCallback onUnlink;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            alignment: Alignment.center,
            child: Text(
              client.initials,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  client.name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.s1),
                Text(
                  client.email,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.appColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.s2),
          AppIconButton(
            icon: Icons.person_remove_outlined,
            tooltip: 'Desasociar cliente',
            onPressed: onUnlink,
            variant: AppIconButtonVariant.destructive,
          ),
        ],
      ),
    );
  }
}

class _UnlinkClientDialog extends StatelessWidget {
  const _UnlinkClientDialog({required this.client});

  final Client client;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: AppColors.rose.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Icon(Icons.person_remove_outlined, color: AppColors.rose),
      ),
      title: const Text('Desasociar cliente'),
      content: Text(
        '¿Deseas desasociar a ${client.name} de tu motel? Perderá el acceso a los servicios asociados a este establecimiento.',
        textAlign: TextAlign.center,
      ),
      actionsPadding: const EdgeInsets.fromLTRB(
        AppSpacing.s5,
        AppSpacing.s2,
        AppSpacing.s5,
        AppSpacing.s5,
      ),
      actions: [
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppButton(
              label: 'Cancelar',
              variant: AppButtonVariant.secondary,
              onPressed: () => Navigator.of(context).pop(false),
            ),
            const SizedBox(height: AppSpacing.s3),
            AppButton(
              label: 'Desasociar',
              variant: AppButtonVariant.destructive,
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        ),
      ],
    );
  }
}
