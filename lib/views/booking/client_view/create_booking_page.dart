import 'package:flutter/material.dart';
import 'package:machuco/core/design_system/design_system.dart';
import 'package:machuco/routes/routes.dart';
import 'package:machuco/views/booking/booking_view_support.dart';

class CreateBookingPage extends StatefulWidget {
  const CreateBookingPage({super.key});

  @override
  State<CreateBookingPage> createState() => _CreateBookingPageState();
}

class _CreateBookingPageState extends State<CreateBookingPage> {
  int _selectedRoom = 0;
  int _guestCount = 2;
  final _rooms = const [
    ('Suite Aurora', 'Habitación 101', 68000, Icons.king_bed_outlined),
    ('Loft Neon', 'Habitación 204', 52000, Icons.bedroom_parent_outlined),
    ('Cabina Prisma', 'Habitación 305', 39000, Icons.bed_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nueva reserva')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.screen),
          children: [
            Text(
              'Motel Eclipse',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: AppSpacing.s2),
            Text(
              'Prototipo visual de selección. La disponibilidad y el precio aún no se calculan.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: context.appColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.s5),
            Text(
              '1. Elige una habitación',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.s3),
            ...List.generate(_rooms.length, (index) {
              final room = _rooms[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.s3),
                child: AppCard(
                  selected: _selectedRoom == index,
                  onTap: () => setState(() => _selectedRoom = index),
                  child: Row(
                    children: [
                      Icon(
                        room.$4,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: AppSpacing.s3),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              room.$1,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text(
                              '${room.$2} · ${formatBookingMoney(room.$3)} / hora',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      if (_selectedRoom == index)
                        const Icon(
                          Icons.check_circle,
                          semanticLabel: 'Seleccionada',
                        ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: AppSpacing.s3),
            Text(
              '2. Fecha y hora',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.s3),
            const Row(
              children: [
                Expanded(
                  child: _SelectionCard(
                    icon: Icons.login_outlined,
                    label: 'Llegada',
                    value: '28 ago · 20:00',
                  ),
                ),
                SizedBox(width: AppSpacing.s3),
                Expanded(
                  child: _SelectionCard(
                    icon: Icons.logout_outlined,
                    label: 'Salida',
                    value: '28 ago · 23:00',
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s5),
            Text('3. Huéspedes', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.s3),
            AppCard(
              child: Row(
                children: [
                  const Icon(Icons.people_outline),
                  const SizedBox(width: AppSpacing.s3),
                  const Expanded(child: Text('Cantidad de huéspedes')),
                  IconButton(
                    onPressed: _guestCount > 1
                        ? () => setState(() => _guestCount--)
                        : null,
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                  Text(
                    '$_guestCount',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  IconButton(
                    onPressed: _guestCount < 4
                        ? () => setState(() => _guestCount++)
                        : null,
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.s5),
            AppCard(
              child: Column(
                children: [
                  _SummaryRow(
                    label: 'Estadía (3 horas)',
                    value: formatBookingMoney(_rooms[_selectedRoom].$3 * 3),
                  ),
                  const SizedBox(height: AppSpacing.s2),
                  const _SummaryRow(label: 'Servicios', value: 'Incluidos'),
                  const Divider(height: AppSpacing.s5),
                  _SummaryRow(
                    label: 'Total estimado',
                    value: formatBookingMoney(_rooms[_selectedRoom].$3 * 3),
                    emphasized: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.s4),
            AppButton(
              label: 'Confirmar y continuar al pago',
              icon: Icons.arrow_forward,
              onPressed: () => Navigator.pushNamed(context, AppRoutes.payment),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectionCard extends StatelessWidget {
  const _SelectionCard({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => AppCard(
    onTap: () => ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Selector visual pendiente de integración.'),
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: AppSpacing.s2),
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        Text(value, style: Theme.of(context).textTheme.titleSmall),
      ],
    ),
  );
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.emphasized = false,
  });
  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: Text(label)),
      Text(
        value,
        style: emphasized
            ? Theme.of(context).textTheme.titleMedium
            : Theme.of(context).textTheme.bodyMedium,
      ),
    ],
  );
}
