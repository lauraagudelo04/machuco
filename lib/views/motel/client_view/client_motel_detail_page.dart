import 'package:flutter/material.dart';
import '../../../core/design_system/design_system.dart';
import './../../../models/motel/motel_model.dart';
import '../../room/client_view/room_client_page.dart';
import './../../../controllers/additional_service/system_admin_view/additional_service_system_administrator_controller.dart';

// Imports de Reseñas
import 'package:machuco/models/review/review_type.dart';
import 'package:machuco/controllers/review/add_review_controller.dart';
import 'package:machuco/widgets/review/review_card.dart';
import 'package:machuco/widgets/review/add_review_sheet.dart';

class ClientMotelDetailPage extends StatelessWidget {
  const ClientMotelDetailPage({super.key, required this.motel});

  final Motel motel;

  @override
  Widget build(BuildContext context) {
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
            // Sección de imagen (Hero)
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
                  // Título y Disponibilidad
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
                  Text(
                    motel.address,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: context.appColors.textSecondary,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.s5),

                  // Descripción y Botón "Ver habitaciones"
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
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => RoomClientPage(motel: motel),
                            ),
                          );
                        },
                      )
                    ],
                  ),
                  const SizedBox(height: AppSpacing.s2),

                  Text(
                    motel.description ??
                        'Sin descripción disponible para este establecimiento.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: context.appColors.textSecondary,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.s5),

                  // Información y Contacto
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

                  // Métodos de Pago
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

                  // Servicios Adicionales
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

                  // WIDGET REAL DE RESEÑAS CONECTADO
                  ReviewsSection(
                    id: motel.id,
                    reviewType: ReviewType.motel,
                    isComplete: true,
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

// Componente Widget de Reseñas
class ReviewsSection extends StatefulWidget {
  const ReviewsSection({
    super.key,
    required this.id,
    required this.reviewType,
    required this.isComplete,
  });

  final String id;
  final ReviewType reviewType;
  final bool isComplete;

  @override
  State<ReviewsSection> createState() => _ReviewsSectionState();
}

class _ReviewsSectionState extends State<ReviewsSection> {
  late final ReviewsController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ReviewsController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final reviews = _controller.getReviewsByType(widget.reviewType, widget.id);
        final average = _controller.getAverageByType(widget.reviewType, widget.id);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  'Reseñas',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(width: AppSpacing.s2),
                const Icon(Icons.star_rounded, color: Color(0xFFFFB300), size: 20),
                const SizedBox(width: AppSpacing.s1),
                Text(
                  average.toStringAsFixed(1),
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                Text(
                  ' (${reviews.length})',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: context.appColors.textMuted,
                      ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s3),

            AppButton(
              label: 'Añadir reseña',
              icon: Icons.rate_review_outlined,
              onPressed: widget.isComplete
                  ? () => AddReviewSheet.show(
                        context,
                        reviewType: widget.reviewType,
                        onSave: (review) => _controller.addReview(review),
                        parentId: widget.id,
                      )
                  : null,
            ),
            const SizedBox(height: AppSpacing.s4),

            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              itemCount: reviews.length,
              itemBuilder: (_, i) => ReviewCard(review: reviews[i]),
            )
          ],
        );
      },
    );
  }
}

// Componentes Auxiliares Privados
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