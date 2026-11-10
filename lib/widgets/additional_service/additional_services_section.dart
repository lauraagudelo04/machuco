import 'package:flutter/material.dart';
import 'package:machuco/controllers/additional_service/system_admin_view/additional_service_system_administrator_controller.dart';
import 'package:machuco/core/design_system/theme/app_theme_extensions.dart';
import 'package:machuco/core/design_system/tokens/app_radius.dart';
import 'package:machuco/core/design_system/tokens/app_spacing.dart';
import 'package:machuco/utils/currency_formatter.dart';

/// Lista de solo lectura con los servicios adicionales activos de un motel.
///
/// Carga los datos al montarse (Firestore, con copia local de respaldo). Se
/// usa donde el cliente solo consulta; para elegirlos al reservar existe la
/// tarjeta de selección de la pantalla de reserva.
class AdditionalServicesSection extends StatefulWidget {
  const AdditionalServicesSection({
    super.key,
    required this.motelId,
    this.title = 'Servicios Adicionales',
    this.controller,
  });

  final String motelId;
  final String title;

  /// Permite inyectar el controller en pruebas; por defecto se crea uno.
  final AdditionalServiceSystemAdministratorController? controller;

  @override
  State<AdditionalServicesSection> createState() =>
      _AdditionalServicesSectionState();
}

class _AdditionalServicesSectionState extends State<AdditionalServicesSection> {
  late final AdditionalServiceSystemAdministratorController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
        widget.controller ??
        AdditionalServiceSystemAdministratorController(motelId: widget.motelId);
    _controller.addListener(_refresh);
    _controller.load();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_refresh);
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final services = _controller.getActiveAdditionalServicesByMotelId(
      widget.motelId,
    );
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.title, style: textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.s3),
        if (_controller.isLoading && services.isEmpty)
          const Center(child: CircularProgressIndicator())
        else if (services.isEmpty)
          Text(
            _controller.syncError ??
                'No hay servicios adicionales disponibles para este motel.',
            style: textTheme.bodyMedium?.copyWith(
              color: context.appColors.textSecondary,
            ),
          )
        else
          for (final service in services)
            _AdditionalServiceTile(
              name: service.name,
              category: service.category,
              description: service.description,
              price: formatCurrencyAmount(service.price),
            ),
      ],
    );
  }
}

class _AdditionalServiceTile extends StatelessWidget {
  const _AdditionalServiceTile({
    required this.name,
    required this.category,
    required this.description,
    required this.price,
  });

  final String name;
  final String category;
  final String description;
  final String price;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.s2),
      padding: const EdgeInsets.all(AppSpacing.s3),
      decoration: BoxDecoration(
        color: context.appColors.elevated,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: context.appColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSpacing.s1),
                Text(
                  category,
                  style: textTheme.bodySmall?.copyWith(
                    color: context.appColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.s1),
                Text(description, style: textTheme.bodySmall),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.s3),
          Text(
            price,
            style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
