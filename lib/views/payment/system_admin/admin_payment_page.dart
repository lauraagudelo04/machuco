import 'package:flutter/material.dart';
import 'package:machuco/core/design_system/design_system.dart';

class AdminFinancePage extends StatelessWidget {
  const AdminFinancePage({super.key});

  @override
  Widget build(BuildContext context) {
    final semantic = context.appColors;
    final hotels = _hotels;
    return Scaffold(
      appBar: AppBar(title: const Text('Finanzas')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.s5),
        children: [
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.hotel_outlined,
                  label: 'Hoteles registrados',
                  value: '${hotels.length}',
                ),
              ),
              const SizedBox(width: AppSpacing.s4),
              Expanded(
                child: _StatCard(
                  icon: Icons.trending_up_outlined,
                  label: 'Ingresos del mes',
                  value: '\$ 12.450.000',
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s5),
          Text('Ingresos por hotel', style: AppTextStyles.h3),
          const SizedBox(height: AppSpacing.s3),
          ...hotels.map((hotel) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.s3),
                child: AppCard(
                  padding: const EdgeInsets.all(AppSpacing.s4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(hotel.name, style: AppTextStyles.h3)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s3, vertical: AppSpacing.s1),
                            decoration: BoxDecoration(
                              color: AppColors.available.withValues(alpha: .12),
                              borderRadius: BorderRadius.circular(AppRadius.pill),
                            ),
                            child: Text('${hotel.rooms} habitaciones', style: AppTextStyles.caption.copyWith(color: AppColors.available)),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.s2),
                      Text('Ingreso mensual', style: AppTextStyles.bodySmall.copyWith(color: semantic.textSecondary)),
                      const SizedBox(height: AppSpacing.s1),
                      Text(hotel.monthlyIncome, style: AppTextStyles.h1.copyWith(color: AppColors.violet)),
                    ],
                  ),
                ),
              )),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final semantic = context.appColors;
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.violet),
          const SizedBox(height: AppSpacing.s3),
          Text(label, style: AppTextStyles.bodySmall.copyWith(color: semantic.textSecondary)),
          const SizedBox(height: AppSpacing.s1),
          Text(value, style: AppTextStyles.h2),
        ],
      ),
    );
  }
}

class _HotelFinance {
  final String name;
  final int rooms;
  final String monthlyIncome;

  const _HotelFinance({required this.name, required this.rooms, required this.monthlyIncome});
}

const _hotels = [
  _HotelFinance(name: 'Motel Paraíso', rooms: 24, monthlyIncome: '\$ 4.200.000'),
  _HotelFinance(name: 'Hotel Mar y Sol', rooms: 18, monthlyIncome: '\$ 3.150.000'),
  _HotelFinance(name: 'Hostal El Descanso', rooms: 12, monthlyIncome: '\$ 2.100.000'),
  _HotelFinance(name: 'Suites Centro', rooms: 30, monthlyIncome: '\$ 3.000.000'),
];