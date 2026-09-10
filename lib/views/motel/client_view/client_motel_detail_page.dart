import 'package:flutter/material.dart';
import '../../../core/design_system/design_system.dart';
import './../../../models/motel/motel_model.dart';
import './../../../routes/routes.dart';
import '../../../controllers/additional_service/system_admin_view/additional_service_system_administrator_controller.dart';

// Importaciones para las reseñas
import 'package:machuco/models/review/review_type.dart';
// Ajusta esta ruta según la ubicación real del archivo donde está ReviewsSection
import 'package:machuco/views/review/add_review_page.dart'; 

class ClientMotelDetailPage extends StatelessWidget {
  const ClientMotelDetailPage({super.key, required this.motel});

  final Motel motel;

  @override
  Widget build(BuildContext context) {
    // Instancia del controlador usando motel.id como String directamente
    final additionalServiceController =
        AdditionalServiceSystemAdministratorController(motelId: motel.id);
    final activeServices =
        additionalServiceController.getActiveAdditionalServicesByMotelId(motel.id);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sección de imagen (Hero) - Lógica adaptada al modelo
            Container(
              height: 300,
              width: double.infinity,
              color: context.appColors.mediaFallback,
              child: Center(
                child: motel.imageUrls.isNotEmpty
                    ? const Icon(Icons.image, size: 64, color: Colors.white)
                    : const Icon(Icons.hotel, size: 64, color: Colors.white),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.s4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Título y Disponibilidad dinámicos
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          motel.name,
                          style: Theme.of(context).textTheme.headlineLarge,
                        ),
                      ),
                      StatusBadge(
                        status: motel.isAvailable
                            ? AppStatus.available
                            : AppStatus.occupied,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.s2),
                  // Dirección dinámica
                  Text(
                    motel.address,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: context.appColors.textSecondary,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.s5),

                  // Fila de Descripción y Botón "Ver habitaciones"
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text('Descripción',
                          style: Theme.of(context).textTheme.headlineSmall),
                      AppButton(
                        label: 'Ver habitaciones',
                        size: AppButtonSize.medium,
                        expanded: false,
                        onPressed: () {
                          // Navigator.pushNamed(
                          //   context,
                          //   AppRoutes.clientRooms,
                          //   arguments: motel,
                          // );
                        },
                      )
                    ],
                  ),
                  const SizedBox(height: AppSpacing.s2),

                  // DESCRIPCIÓN DINÁMICA
                  Text(
                    motel.description ??
                        'Sin descripción disponible para este establecimiento.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: context.appColors.textSecondary,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.s5),

                  // SECCIÓN: Información y Contacto
                  Text('Información y Contacto',
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: AppSpacing.s3),
                  _InfoRow(
                      icon: Icons.phone_outlined,
                      label: 'Teléfono',
                      value: motel.phone),
                  const SizedBox(height: AppSpacing.s2),
                  _InfoRow(
                      icon: Icons.email_outlined,
                      label: 'Correo',
                      value: motel.email),
                  const SizedBox(height: AppSpacing.s2),
                  _InfoRow(
                      icon: Icons.domain_outlined,
                      label: 'NIT',
                      value: motel.nit),
                  const SizedBox(height: AppSpacing.s2),
                  _InfoRow(
                      icon: Icons.bed_outlined,
                      label: 'Capacidad',
                      value: '${motel.roomCount} habitaciones en total'),

                  if (motel.generalLocation != null &&
                      motel.generalLocation!.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.s2),
                    _InfoRow(
                        icon: Icons.location_on_outlined,
                        label: 'Ubicación',
                        value: motel.generalLocation!),
                  ],

                  const SizedBox(height: AppSpacing.s5),

                  // Métodos de Pago dinámicos
                  Text('Métodos de Pago',
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: AppSpacing.s3),
                  Wrap(
                    spacing: AppSpacing.s2,
                    runSpacing: AppSpacing.s2,
                    children: motel.paymentMethods
                        .map((method) => _ServiceChip(label: method))
                        .toList(),
                  ),
                  const SizedBox(height: AppSpacing.s5),

                  // SERVICIOS ADICIONALES DINÁMICOS
                  Text('Servicios Adicionales',
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: AppSpacing.s3),
                  if (activeServices.isEmpty)
                    Text(
                      'No hay servicios adicionales disponibles para este motel.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: context.appColors.textSecondary,
                          ),
                    )
                  else
                    Wrap(
                      spacing: AppSpacing.s2,
                      runSpacing: AppSpacing.s2,
                      children: activeServices
                          .map(
                            (service) => _ServiceChip(
                              label:
                                  '${service.name} (\$${service.price.toString()})',
                            ),
                          )
                          .toList(),
                    ),
                  const SizedBox(height: AppSpacing.s5),

                  const Divider(),
                  const SizedBox(height: AppSpacing.s4),

                  // --- SECCIÓN DE RESEÑAS VINCULADA ---
                  ReviewsSection(
                    id: motel.id,
                    reviewType: ReviewType.motel, // O el valor de enum correspondiente
                    isComplete: true, // Habilita el botón 'Añadir reseña'
                  ),
                  const SizedBox(height: AppSpacing.s4),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Componentes Privados Auxiliares ---

class _InfoRow extends StatelessWidget {
  const _InfoRow(
      {required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: context.appColors.textSecondary),
        const SizedBox(width: AppSpacing.s2),
        Text(
          '$label: ',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        Expanded(
          child: Text(
            value,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: context.appColors.textSecondary),
          ),
        ),
      ],
    );
  }
}

class _ServiceChip extends StatelessWidget {
  const _ServiceChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s3, vertical: AppSpacing.s1),
      decoration: BoxDecoration(
        color: context.appColors.elevated,
        borderRadius: BorderRadius.circular(100.0),
        border: Border.all(color: context.appColors.border),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}