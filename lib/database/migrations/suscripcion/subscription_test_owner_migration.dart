import 'package:floor/floor.dart';
import 'package:sqflite/sqflite.dart' as sqflite;

/// Los esquemas de suscripción y pagos se crean por Floor en instalaciones
/// nuevas y por las migraciones anteriores en bases existentes.
final migration6To7 = Migration(6, 7, seedSubscriptionTestOwner);

Future<void> seedSubscriptionTestOwner(sqflite.Database database) async {
  await database.execute('''
    INSERT INTO subscriptions (
      userEmail, planId, planName, motelName, amount, billingPeriod,
      nextBillingDate, status, features
    )
    SELECT
      'propietario.test@machuco.com', 2, 'Premium', 'Motel Machuco',
      150000, 'Mensual', 1793509200000000, 'active',
      '["Gestión de habitaciones","Reportes"]'
    WHERE NOT EXISTS (
      SELECT 1 FROM subscriptions
      WHERE lower(trim(userEmail)) = 'propietario.test@machuco.com'
    )
  ''');
}
