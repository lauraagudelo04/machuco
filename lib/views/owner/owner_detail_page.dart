import 'package:flutter/material.dart';

import 'package:machuco/core/design_system/components/app_button.dart';
import 'package:machuco/core/design_system/theme/app_theme_extensions.dart';
import 'package:machuco/core/design_system/tokens/app_spacing.dart';

import 'owner_models.dart';
import 'owner_summary.dart';

const _compactWidthBreakpoint = 360.0;
const _detailMaxWidth = 520.0;

/// Detalle de solo lectura de un propietario.
///
/// Al cerrarse devuelve `true` si el usuario pidió editarlo, para que la lista
/// abra el formulario sin apilar una pantalla más.
class OwnerDetailPage extends StatelessWidget {
  const OwnerDetailPage({super.key, required this.owner});

  final OwnerFormData owner;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detalle del propietario')),
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontalPadding =
                constraints.maxWidth < _compactWidthBreakpoint
                ? AppSpacing.screenCompact
                : AppSpacing.screen;
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _detailMaxWidth),
                child: ListView(
                  padding: EdgeInsets.symmetric(
                    horizontal: horizontalPadding,
                    vertical: AppSpacing.s5,
                  ),
                  children: [OwnerSummary(owner: owner)],
                ),
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          color: context.appColors.canvas,
          border: Border(top: BorderSide(color: context.appColors.border)),
        ),
        child: SafeArea(
          top: false,
          minimum: const EdgeInsets.all(AppSpacing.s4),
          child: AppButton(
            label: 'Editar teléfono',
            icon: Icons.edit_outlined,
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ),
      ),
    );
  }
}
