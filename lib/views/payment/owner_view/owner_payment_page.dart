import 'package:flutter/material.dart';
import 'package:machuco/controllers/payment/payment_controller.dart';
import 'package:machuco/core/design_system/design_system.dart';
import 'package:machuco/models/payment/payment.dart';

class UserReservationsPage extends StatefulWidget {
  const UserReservationsPage({super.key});

  @override
  State<UserReservationsPage> createState() => _UserReservationsPageState();
}

class _UserReservationsPageState extends State<UserReservationsPage> {
  final List<PaymentReservation> _reservations = List.of(
    PaymentController.reservations,
  );

  void _markAsPaid(String id) {
    setState(() {
      final index = _reservations.indexWhere((r) => r.id == id);
      if (index != -1) {
        _reservations[index] = PaymentController.markAsPaid(
          _reservations[index],
        );
      }
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Pago registrado en efectivo'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final semantic = context.appColors;
    final pending = _reservations
        .where((r) => r.status == PaymentStatus.pending)
        .toList();
    final paid = _reservations
        .where((r) => r.status == PaymentStatus.paid)
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Mis reservas')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.s5),
        children: [
          if (pending.isNotEmpty) ...[
            Text('Pendientes de pago', style: AppTextStyles.h3),
            const SizedBox(height: AppSpacing.s3),
            ...pending.map(
              (r) => Padding(
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
                                Text(
                                  r.room,
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: semantic.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          StatusBadge(
                            status: _appStatus(r.status),
                            size: StatusBadgeSize.small,
                          ),
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
              ),
            ),
          ],
          if (paid.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.s5),
            Text('Pagadas', style: AppTextStyles.h3),
            const SizedBox(height: AppSpacing.s3),
            ...paid.map(
              (r) => Padding(
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
                            Text(
                              r.room,
                              style: AppTextStyles.bodySmall.copyWith(
                                color: semantic.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        r.amount,
                        style: AppTextStyles.bodyLarge.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.available,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
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
        Text(
          label,
          style: AppTextStyles.body.copyWith(color: semantic.textSecondary),
        ),
      ],
    );
  }
}

AppStatus _appStatus(PaymentStatus status) => switch (status) {
  PaymentStatus.pending => AppStatus.reserved,
  PaymentStatus.confirmed => AppStatus.upcoming,
  PaymentStatus.paid => AppStatus.active,
  PaymentStatus.completed => AppStatus.completed,
  PaymentStatus.cancelled => AppStatus.cancelled,
};
