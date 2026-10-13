import 'package:flutter/material.dart';
import 'package:machuco/core/design_system/design_system.dart';
import 'package:machuco/repositories/booking/booking_repository.dart';
import 'package:machuco/repositories/booking/reservation_category_repository.dart';
import 'package:machuco/routes/routes.dart';
import 'package:machuco/views/login/login_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  ReservationCategoryRepositoryProvider.useDatabase();
  BookingRepositoryProvider.useDatabase();
  runApp(const MachucoApp());
}

class MachucoApp extends StatelessWidget {
  const MachucoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MACHUCO',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      onGenerateRoute: AppRoutes.onGenerateRoute,
      home: const LoginPage(),
    );
  }
}
