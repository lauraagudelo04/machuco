import 'package:flutter/material.dart';
import 'package:machuco/core/design_system/design_system.dart';
import 'views/payment/system_admin/admin_payment_page.dart';
import 'views/payment/client/client_payment_page.dart';
import 'views/payment/owner/owner_payment_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MACHUCO',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      home: const HomeSelector(),
    );
  }
}

class HomeSelector extends StatelessWidget {
  const HomeSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final semantic = context.appColors;

    return Scaffold(
      appBar: AppBar(title: const Text('Vistas de pago')),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.s5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppButton(
              label: 'Administrador · Finanzas',
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminFinancePage())),
              icon: Icons.admin_panel_settings_outlined,
            ),
            const SizedBox(height: AppSpacing.s3),
            AppButton(
              label: 'Cliente · Panel de control',
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ClientDashboardPage())),
              icon: Icons.dashboard_outlined,
              variant: AppButtonVariant.secondary,
            ),
            const SizedBox(height: AppSpacing.s3),
            AppButton(
              label: 'Usuario · Mis reservas',
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UserReservationsPage())),
              icon: Icons.person_outline_rounded,
              variant: AppButtonVariant.secondary,
            ),
          ],
        ),
      ),
    );
  }
}
