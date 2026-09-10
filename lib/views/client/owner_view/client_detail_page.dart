import 'package:flutter/material.dart';
import 'package:machuco/core/design_system/components/app_card.dart';
import 'package:machuco/core/design_system/tokens/app_radius.dart';
import 'package:machuco/core/design_system/tokens/app_spacing.dart';
import 'package:machuco/core/design_system/theme/app_theme_extensions.dart';
import 'package:machuco/models/client/client.dart';

class ClientDetailPage extends StatelessWidget {
  const ClientDetailPage({super.key, required this.client});

  final Client client;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detalle del cliente')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.screen),
          children: [
            _buildHeader(context),
            const SizedBox(height: AppSpacing.s6),
            _DetailSection(
              title: 'Información personal',
              children: [
                _InfoRow(
                  icon: Icons.person_outline,
                  label: 'Nombre',
                  value: client.name,
                ),
                _InfoRow(
                  icon: Icons.phone_outlined,
                  label: 'Teléfono',
                  value: client.phone,
                ),
                _InfoRow(
                  icon: Icons.email_outlined,
                  label: 'Correo electrónico',
                  value: client.email,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return AppCard(
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(AppRadius.xl),
            ),
            alignment: Alignment.center,
            child: Text(
              client.initials,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.s3),
          Text(
            client.name,
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
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
    );
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.s3),
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.s1),
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) const Divider(height: 1),
                children[i],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
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
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s4,
        vertical: AppSpacing.s3,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(
              icon,
              size: 20,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: AppSpacing.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: context.appColors.textMuted,
                  ),
                ),
                const SizedBox(height: AppSpacing.s1),
                Text(
                  value,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
