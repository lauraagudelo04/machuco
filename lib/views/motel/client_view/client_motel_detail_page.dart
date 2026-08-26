import 'package:flutter/material.dart';
import '../../../core/design_system/design_system.dart';

class ClientMotelDetailPage extends StatelessWidget {
  const ClientMotelDetailPage({super.key, required this.motelName});

  final String motelName;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true, // Para que la imagen cubra el tope si es necesario
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
              child: const Center(child: Icon(Icons.hotel, size: 64, color: Colors.white)),
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
                          motelName,
                          style: Theme.of(context).textTheme.headlineLarge,
                        ),
                      ),
                      const StatusBadge(status: AppStatus.available),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.s2),
                  Text(
                    'Rionegro, Antioquia - A 5 min del centro',
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
                      Text('Descripción', style: Theme.of(context).textTheme.headlineSmall),
                      AppButton(
                        label: 'Ver habitaciones',
                        size: AppButtonSize.medium, 
                        expanded: false, 
                        onPressed: () {
                          // TODO: Navegar a la lista de habitaciones
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.s2),
                  Text(
                    'Disfruta de nuestras instalaciones de lujo, diseñadas para tu máximo confort y privacidad. Contamos con servicio a la habitación 24/7 y parqueadero privado.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: context.appColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s5),

                  // Servicios Adicionales quemados
                  Text('Servicios Adicionales', style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: AppSpacing.s3),
                  Wrap(
                    spacing: AppSpacing.s2, // Espacio horizontal
                    runSpacing: AppSpacing.s2, // Espacio vertical
                    children: const [
                      _ServiceChip(label: 'Jacuzzi'),
                      _ServiceChip(label: 'Wi-Fi de alta velocidad'),
                      _ServiceChip(label: 'Bar / Restaurante'),
                      _ServiceChip(label: 'Silla Erótica'),
                      _ServiceChip(label: 'TV con Streaming'),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.s5),

                  const Divider(),
                  const SizedBox(height: AppSpacing.s4),

                  // Sección de Reseñas y Botón Agregar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Reseñas', style: Theme.of(context).textTheme.headlineSmall),
                      TextButton(
                        onPressed: () {
                          // TODO: Abrir modal para agregar reseña
                        },
                        child: const Text('Agregar reseña'),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.s3),

                  // Lista de reseñas
                  ListView.separated(
                    padding: EdgeInsets.zero,
                    physics: const NeverScrollableScrollPhysics(),
                    shrinkWrap: true, 
                    itemCount: 3, // 3 reseñas de prueba
                    separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.s3),
                    itemBuilder: (context, index) {
                      return _ReviewItem(
                        userName: 'Usuario Anónimo ${index + 1}',
                        rating: index == 0 ? 5 : 4, 
                        comment: 'Excelente lugar, muy limpio y la atención fue rápida. La privacidad es total. Volveremos pronto.',
                      );
                    },
                  ),
                  const SizedBox(height: AppSpacing.s4), // Espaciado final normal para el scroll
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

class _ServiceChip extends StatelessWidget {
  const _ServiceChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s3, vertical: AppSpacing.s1),
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

class _ReviewItem extends StatelessWidget {
  const _ReviewItem({
    required this.userName,
    required this.rating,
    required this.comment,
  });

  final String userName;
  final int rating;
  final String comment;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.s3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Avatar genérico
              CircleAvatar(
                backgroundColor: context.appColors.mediaFallback,
                radius: 16,
                child: Icon(Icons.person, size: 20, color: context.appColors.textDisabled),
              ),
              const SizedBox(width: AppSpacing.s2),
              // Nombre
              Expanded(
                child: Text(
                  userName,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              // Estrellas quemadas
              Row(
                children: List.generate(5, (index) {
                  return Icon(
                    index < rating ? Icons.star : Icons.star_border,
                    size: 16,
                    color: Colors.amber,
                  );
                }),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s2),
          // Comentario
          Text(
            comment,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: context.appColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}