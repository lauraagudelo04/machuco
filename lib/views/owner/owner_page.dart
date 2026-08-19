import 'package:flutter/material.dart';

import 'package:machuco/core/design_system/components/app_card.dart';
import 'package:machuco/core/design_system/components/app_feedback.dart';
import 'package:machuco/core/design_system/components/app_icon_button.dart';
import 'package:machuco/core/design_system/theme/app_theme_extensions.dart';
import 'package:machuco/core/design_system/tokens/app_spacing.dart';

import 'owner_detail_page.dart';
import 'owner_form_page.dart';
import 'owner_models.dart';
import 'owner_summary.dart';

const _compactWidthBreakpoint = 360.0;
const _listMaxWidth = 640.0;

/// Lista de propietarios de moteles: es el punto de entrada del módulo.
///
/// Mientras no exista capa de datos, los propietarios viven en el estado de
/// esta pantalla y los cambios se pierden al reiniciar la aplicación.
class OwnerPage extends StatefulWidget {
  const OwnerPage({super.key});

  @override
  State<OwnerPage> createState() => _OwnerPageState();
}

class _OwnerPageState extends State<OwnerPage> {
  final List<OwnerFormData> _owners = [
    const OwnerFormData(
      fullName: 'Laura Gómez Restrepo',
      documentType: DocumentType.citizenshipCard,
      documentNumber: '1020304050',
      email: 'laura.gomez@machuco.com',
      phone: '+57 300 123 4567',
      address: 'Calle 10 # 43-25, Medellín',
    ),
    const OwnerFormData(
      fullName: 'Inversiones Machuco S.A.S.',
      documentType: DocumentType.taxId,
      documentNumber: '900123456-7',
      email: 'contacto@inversionesmachuco.com',
      phone: '+57 604 444 5566',
      address: 'Carrera 50 # 12-80, Rionegro',
    ),
    const OwnerFormData(
      fullName: 'Simón Restrepo Vélez',
      documentType: DocumentType.foreignerCard,
      documentNumber: '345678',
      email: 'simon.restrepo@machuco.com',
      phone: '+57 311 987 6543',
      isActive: false,
    ),
  ];

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _createOwner() async {
    final created = await Navigator.of(context).push<OwnerFormData>(
      MaterialPageRoute(builder: (_) => const OwnerFormPage()),
    );
    if (created == null || !mounted) return;
    setState(() => _owners.add(created));
  }

  Future<void> _editOwner(OwnerFormData owner) async {
    final updated = await Navigator.of(context).push<OwnerFormData>(
      MaterialPageRoute(builder: (_) => OwnerFormPage(initialData: owner)),
    );
    if (updated == null || !mounted) return;
    final index = _owners.indexOf(owner);
    if (index == -1) return;
    setState(() => _owners[index] = updated);
    _showMessage('Cambios guardados correctamente.');
  }

  Future<void> _openDetail(OwnerFormData owner) async {
    final wantsToEdit = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => OwnerDetailPage(owner: owner)),
    );
    if (wantsToEdit != true || !mounted) return;
    await _editOwner(owner);
  }

  Future<void> _toggleActiveState(OwnerFormData owner) async {
    // Inactivar deja al propietario sin operación, así que se confirma; volver
    // a activarlo es inocuo y no necesita confirmación.
    if (owner.isActive && !await _confirmDeactivation(owner)) return;
    if (!mounted) return;
    final index = _owners.indexOf(owner);
    if (index == -1) return;
    setState(() => _owners[index] = owner.copyWith(isActive: !owner.isActive));
    _showMessage(
      owner.isActive
          ? '${owner.fullName} quedó inactivo.'
          : '${owner.fullName} quedó activo.',
    );
  }

  Future<bool> _confirmDeactivation(OwnerFormData owner) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Inactivar propietario'),
        content: Text(
          '${owner.fullName} dejará de administrar sus moteles y de recibir '
          'reservas. Puedes volver a activarlo cuando quieras.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Inactivar'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Propietarios')),
      body: SafeArea(
        bottom: false,
        child: _owners.isEmpty
            ? AppEmptyState(
                icon: Icons.people_outline,
                title: 'Aún no hay propietarios',
                message:
                    'Registra al primer propietario para asociarle sus moteles.',
                actionLabel: 'Crear propietario',
                onAction: _createOwner,
              )
            : LayoutBuilder(
                builder: (context, constraints) {
                  final horizontalPadding =
                      constraints.maxWidth < _compactWidthBreakpoint
                      ? AppSpacing.screenCompact
                      : AppSpacing.screen;
                  return Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: _listMaxWidth,
                      ),
                      child: ListView.separated(
                        padding: EdgeInsets.fromLTRB(
                          horizontalPadding,
                          AppSpacing.s5,
                          horizontalPadding,
                          // Deja respirar la última tarjeta por encima del FAB.
                          AppSpacing.s12 + AppSpacing.s5,
                        ),
                        itemCount: _owners.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: AppSpacing.s3),
                        itemBuilder: (context, index) {
                          final owner = _owners[index];
                          return _OwnerCard(
                            owner: owner,
                            onDetail: () => _openDetail(owner),
                            onEdit: () => _editOwner(owner),
                            onToggleActive: () => _toggleActiveState(owner),
                          );
                        },
                      ),
                    ),
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createOwner,
        tooltip: 'Crear propietario',
        child: const Icon(Icons.add),
      ),
    );
  }
}

/// Tarjeta de un propietario con sus acciones disponibles.
class _OwnerCard extends StatelessWidget {
  const _OwnerCard({
    required this.owner,
    required this.onDetail,
    required this.onEdit,
    required this.onToggleActive,
  });

  final OwnerFormData owner;
  final VoidCallback onDetail;
  final VoidCallback onEdit;
  final VoidCallback onToggleActive;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return AppCard(
      onTap: onDetail,
      semanticLabel: '${owner.fullName}, ${owner.documentLabel}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(owner.fullName, style: textTheme.titleMedium),
              ),
              const SizedBox(width: AppSpacing.s2),
              OwnerStatusChip(isActive: owner.isActive),
            ],
          ),
          const SizedBox(height: AppSpacing.s2),
          _OwnerDetailLine(
            icon: Icons.badge_outlined,
            text: owner.documentLabel,
          ),
          _OwnerDetailLine(icon: Icons.mail_outline, text: owner.email),
          _OwnerDetailLine(icon: Icons.phone_outlined, text: owner.phone),
          const SizedBox(height: AppSpacing.s2),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              AppIconButton(
                icon: Icons.visibility_outlined,
                tooltip: 'Ver detalle de ${owner.fullName}',
                onPressed: onDetail,
              ),
              const SizedBox(width: AppSpacing.s2),
              AppIconButton(
                icon: Icons.edit_outlined,
                tooltip: 'Editar a ${owner.fullName}',
                onPressed: onEdit,
              ),
              const SizedBox(width: AppSpacing.s2),
              AppIconButton(
                icon: owner.isActive
                    ? Icons.block_outlined
                    : Icons.check_circle_outline,
                tooltip: owner.isActive
                    ? 'Inactivar a ${owner.fullName}'
                    : 'Activar a ${owner.fullName}',
                variant: owner.isActive
                    ? AppIconButtonVariant.destructive
                    : AppIconButtonVariant.standard,
                onPressed: onToggleActive,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OwnerDetailLine extends StatelessWidget {
  const _OwnerDetailLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final color = context.appColors.textSecondary;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.s1),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: AppSpacing.s2),
          Expanded(
            child: Text(
              text,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: color),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
