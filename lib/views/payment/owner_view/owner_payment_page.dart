import 'package:flutter/material.dart';
import 'package:machuco/core/design_system/design_system.dart';
import '../payment_models.dart';

class UserReservationsPage extends StatefulWidget {
  const UserReservationsPage({super.key});

  @override
  State<UserReservationsPage> createState() => _UserReservationsPageState();
}

class _UserReservationsPageState extends State<UserReservationsPage> {
  final List<_UserReservation> _reservations = [
    _UserReservation(id: '1', motel: 'Motel Paraíso', room: 'Habitación 305 · Suite', date: '22 jul 2026', amount: '\$ 180.000', status: ReservationStatus.pending),
    _UserReservation(id: '2', motel: 'Motel Paraíso', room: 'Habitación 112 · Junior', date: '25 jul 2026', amount: '\$ 120.000', status: ReservationStatus.pending),
    _UserReservation(id: '3', motel: 'Hotel Mar y Sol', room: 'Habitación 208 · Deluxe', date: '28 jul 2026', amount: '\$ 210.000', status: ReservationStatus.pending),
  ];

  void _markAsPaid(String id) {
    setState(() {
      final index = _reservations.indexWhere((r) => r.id == id);
      if (index != -1) {
        _reservations[index] = _UserReservation(
          id: _reservations[index].id,
          motel: _reservations[index].motel,
          room: _reservations[index].room,
          date: _reservations[index].date,
          amount: _reservations[index].amount,
          status: ReservationStatus.paid,
        );
      }
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Pago registrado en efectivo'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final semantic = context.appColors;
    final pending = _reservations.where((r) => r.status == ReservationStatus.pending).toList();
    final paid = _reservations.where((r) => r.status == ReservationStatus.paid).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Mis reservas')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.s5),
        children: [
          if (pending.isNotEmpty) ...[
            Text('Pendientes de pago', style: AppTextStyles.h3),
            const SizedBox(height: AppSpacing.s3),
            ...pending.map((r) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.s3),
                  child: AppCard(
                    padding: const EdgeInsets.all(AppSpacing.s4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(r.motel, style: AppTextStyles.h3),
                                  const SizedBox(height: AppSpacing.s1),
                                  Text(r.room, style: AppTextStyles.bodySmall.copyWith(color: semantic.textSecondary)),
                                ],
                              ),
                            ),
                            StatusBadge(status: r.status.toAppStatus, size: StatusBadgeSize.small),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.s3),
                        _Row(icon: Icons.event_outlined, label: r.date),
                        const SizedBox(height: AppSpacing.s2),
                        _Row(icon: Icons.attach_money_rounded, label: r.amount),
                        const SizedBox(height: AppSpacing.s4),
                        SizedBox(
                          width: double.infinity,
                          child: AppButton(
                            label: 'Pagar en efectivo',
                            variant: AppButtonVariant.secondary,
                            onPressed: () => _markAsPaid(r.id),
                            icon: Icons.money_outlined,
                          ),
                        ),
                      ],
                    ),
                  ),
                )),
          ],
          if (paid.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.s5),
            Text('Pagadas', style: AppTextStyles.h3),
            const SizedBox(height: AppSpacing.s3),
            ...paid.map((r) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.s3),
                  child: AppCard(
                    padding: const EdgeInsets.all(AppSpacing.s4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(r.motel, style: AppTextStyles.bodyLarge),
                              const SizedBox(height: AppSpacing.s1),
                              Text(r.room, style: AppTextStyles.bodySmall.copyWith(color: semantic.textSecondary)),
                            ],
                          ),
                        ),
                        Text(r.amount, style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w700, color: AppColors.available)),
                      ],
                    ),
                  ),
                )),
          ],
          if (pending.isEmpty && paid.isEmpty)
            AppEmptyState(
              icon: Icons.confirmation_number_outlined,
              title: 'Sin reservas',
              message: 'Aún no tienes reservas creadas.',
            ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final semantic = context.appColors;
    return Row(
      children: [
        Icon(icon, size: 18, color: semantic.textSecondary),
        const SizedBox(width: AppSpacing.s2),
        Text(label, style: AppTextStyles.body.copyWith(color: semantic.textSecondary)),
      ],
    );
  }
}

class _UserReservation {
  final String id;
  final String motel;
  final String room;
  final String date;
  final String amount;
  final ReservationStatus status;

  const _UserReservation({required this.id, required this.motel, required this.room, required this.date, required this.amount, required this.status});
}