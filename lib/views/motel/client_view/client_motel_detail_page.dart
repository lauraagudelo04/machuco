import 'package:flutter/material.dart';
import '../../../core/design_system/design_system.dart';
import './../../../models/motel/motel_model.dart'; // Asegúrate de importar el modelo

class ClientMotelDetailPage extends StatelessWidget {
  // Ahora recibimos el objeto Motel completo en lugar de solo el nombre
  const ClientMotelDetailPage({super.key, required this.motel});

  final Motel motel;

  @override
  Widget build(BuildContext context) {
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
                    ? const Icon(Icons.image, size: 64, color: Colors.white) // Simulación de imagen real
                    : const Icon(Icons.hotel, size: 64, color: Colors.white), // Fallback
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
                        status: motel.isAvailable ? AppStatus.available : AppStatus.occupied,
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
                      Text('Descripción', style: Theme.of(context).textTheme.headlineSmall),
                      AppButton(
                        label: 'Ver habitaciones',
                        size: AppButtonSize.medium, 
                        expanded: false, 
                        onPressed: () {
                          // TODO: Navegar a la lista de habitaciones pasando el motel.id
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.s2),
                  // Descripción (Sigue quemada porque no está en el modelo, podríamos agregarla luego)
                  Text(
                    'Disfruta de nuestras instalaciones de lujo, diseñadas para tu máximo confort y privacidad. Contamos con servicio a la habitación 24/7 y parqueadero privado.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: context.appColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s5),
                  
                  // NUEVA SECCIÓN: Información y Contacto (Usando los datos del modelo)
                  Text('Información y Contacto', style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: AppSpacing.s3),
                  _InfoRow(icon: Icons.phone_outlined, label: 'Teléfono', value: motel.phone),
                  const SizedBox(height: AppSpacing.s2),
                  _InfoRow(icon: Icons.email_outlined, label: 'Correo', value: motel.email),
                  const SizedBox(height: AppSpacing.s2),
                  _InfoRow(icon: Icons.domain_outlined, label: 'NIT', value: motel.nit),
                  const SizedBox(height: AppSpacing.s2),
                  _InfoRow(icon: Icons.bed_outlined, label: 'Capacidad', value: '${motel.roomCount} habitaciones en total'),
                  const SizedBox(height: AppSpacing.s5),

                  // Métodos de Pago dinámicos
                  Text('Métodos de Pago', style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: AppSpacing.s3),
                  Wrap(
                    spacing: AppSpacing.s2,
                    runSpacing: AppSpacing.s2,
                    children: motel.paymentMethods.map((method) => _ServiceChip(label: method)).toList(),
                  ),
                  const SizedBox(height: AppSpacing.s5),

                  // Servicios Adicionales (Aún quemados, ideal para un nuevo modelo en el futuro)
                  Text('Servicios Adicionales', style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: AppSpacing.s3),
                  Wrap(
                    spacing: AppSpacing.s2, 
                    runSpacing: AppSpacing.s2, 
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

                  // Sección de Reseñas y Botón Agregar (Aún quemados)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Reseñas', style: Theme.of(context).textTheme.headlineSmall),
                      TextButton(
                        onPressed: () {},
                        child: const Text('Agregar reseña'),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.s3),

                  ListView.separated(
                    padding: EdgeInsets.zero,
                    physics: const NeverScrollableScrollPhysics(),
                    shrinkWrap: true, 
                    itemCount: 3, 
                    separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.s3),
                    itemBuilder: (context, index) {
                      return _ReviewItem(
                        userName: 'Usuario Anónimo ${index + 1}',
                        rating: index == 0 ? 5 : 4, 
                        comment: 'Excelente lugar, muy limpio y la atención fue rápida. La privacidad es total. Volveremos pronto.',
                      );
                    },
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

// Nuevo widget para mostrar filas de información con ícono
class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label, required this.value});
  
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
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        Expanded(
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: context.appColors.textSecondary),
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
              CircleAvatar(
                backgroundColor: context.appColors.mediaFallback,
                radius: 16,
                child: Icon(Icons.person, size: 20, color: context.appColors.textDisabled),
              ),
              const SizedBox(width: AppSpacing.s2),
              Expanded(
                child: Text(
                  userName,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
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