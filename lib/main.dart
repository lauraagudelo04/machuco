import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:machuco/database/app_database.dart';
import 'package:machuco/core/design_system/design_system.dart';
import 'package:machuco/firebase_options.dart';
import 'package:machuco/routes/routes.dart';
import 'package:machuco/views/login/login_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await AppDatabaseProvider.database;
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
