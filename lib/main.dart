import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:machuco/database/app_database.dart';
import 'package:machuco/core/design_system/design_system.dart';
import 'package:machuco/firebase_options.dart';
import 'package:machuco/repositories/booking/booking_repository.dart';
import 'package:machuco/repositories/booking/reservation_category_repository.dart';
import 'package:machuco/routes/routes.dart';
import 'package:machuco/service/analytics/analytics_service.dart';
import 'package:machuco/service/crashlytics/crash_reporting_service.dart';
import 'package:machuco/views/login/login_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  CrashReporting.install(FirebaseCrashReporter());
  AnalyticsServiceProvider.useFirebase();
  await AppDatabaseProvider.database;
  ReservationCategoryRepositoryProvider.useDatabase();
  BookingRepositoryProvider.useDatabase();
  runApp(const MachucoApp());
}

class MachucoApp extends StatelessWidget {
  const MachucoApp({super.key});

  /// Reports every named screen to Firebase Analytics.
  static final _analyticsObserver = AnalyticsRouteObserver(
    rootScreenName: 'login',
  );

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MACHUCO',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      onGenerateRoute: AppRoutes.onGenerateRoute,
      navigatorObservers: [_analyticsObserver],
      home: const LoginPage(),
    );
  }
}
