import 'package:flutter/material.dart';
import 'package:machuco/controllers/payment/payment_controller.dart';
import 'package:machuco/core/design_system/design_system.dart';

class ClientDashboardPage extends StatefulWidget {
  const ClientDashboardPage({super.key});

  @override
  State<ClientDashboardPage> createState() => _ClientDashboardPageState();
}

class _ClientDashboardPageState extends State<ClientDashboardPage> {
  @override
  Widget build(BuildContext context) {
    final semantic = context.appColors;
    return Scaffold(
      appBar: AppBar(title: const Text('Panel de control')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.s5),
        children: [
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.calendar_month_outlined,
                  label: 'Ingresos del mes',
                  value: '\$ 8.200.000',
                ),
              ),
              const SizedBox(width: AppSpacing.s4),
              Expanded(
                child: _StatCard(
                  icon: Icons.today_outlined,
                  label: 'Ingresos de hoy',
                  value: '\$ 320.000',
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s5),
          Text('Reservas pendientes de pago', style: AppTextStyles.h3),
          const SizedBox(height: AppSpacing.s3),
          ...PaymentController.pendingPayments.map(
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
                          Text(r.client, style: AppTextStyles.bodyLarge),
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
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.s5),
          Text('Comisiones', style: AppTextStyles.h3),
          const SizedBox(height: AppSpacing.s3),
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.s4),
            child: Row(
              children: [
                Icon(Icons.percent_outlined, color: AppColors.purple),
                const SizedBox(width: AppSpacing.s3),
                Expanded(
                  child: Text(
                    'Comisión acumulada',
                    style: AppTextStyles.bodyLarge,
                  ),
                ),
                Text(
                  '\$ 540.000',
                  style: AppTextStyles.bodyLarge.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.fuchsia,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.s5),
          Text('Clientes recientes', style: AppTextStyles.h3),
          const SizedBox(height: AppSpacing.s3),
          ...PaymentController.recentClients.map(
            (c) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.s3),
              child: AppCard(
                padding: const EdgeInsets.all(AppSpacing.s4),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: AppColors.violet.withValues(alpha: .15),
                      child: Text(
                        c.initials,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.violet,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s3),
                    Expanded(
                      child: Text(c.name, style: AppTextStyles.bodyLarge),
                    ),
                    Text(
                      c.reservations,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: semantic.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.violet),
          const SizedBox(height: AppSpacing.s3),
          Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: context.appColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.s1),
          Text(value, style: AppTextStyles.h2),
        ],
      ),
    );
  }
}
