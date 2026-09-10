import 'package:flutter/foundation.dart';
import 'package:machuco/core/design_system/components/status_badge.dart';
import 'package:machuco/models/subscription/subscription.dart';

/// Controlador que administra el estado y las operaciones de la suscripción del propietario.
class OwnerSubscriptionController extends ChangeNotifier {
  final SubscriptionDetails _subscription = SubscriptionDetails(
    id: 'sub-001',
    planName: 'Plan Premium Pro',
    motelName: 'Motel Paraíso Real',
    amount: 150000,
    billingPeriod: 'Mensual',
    nextBillingDate: DateTime(2026, 9, 25),
    status: AppStatus.active,
    features: const [
      'Gestión de hasta 20 habitaciones',
      'Panel de reportes y estadísticas en tiempo real',
      'Visibilidad prioritaria en búsquedas de clientes',
      'Soporte 24/7 y pasarela de pagos integrada',
    ],
  );

  final List<SubscriptionPayment> _payments = [
    SubscriptionPayment(
      id: 'pay-101',
      date: DateTime(2026, 8, 25),
      amount: 150000,
      paymentMethod: 'Transferencia Bancaria',
      reference: 'TRANS-99482',
      status: AppStatus.completed,
    ),
    SubscriptionPayment(
      id: 'pay-100',
      date: DateTime(2026, 7, 25),
      amount: 150000,
      paymentMethod: 'Tarjeta de Crédito',
      reference: 'TC-***4092',
      status: AppStatus.completed,
    ),
  ];

  SubscriptionDetails get subscription => _subscription;

  List<SubscriptionPayment> get payments => List.unmodifiable(_payments);

  void addPayment({
    required int amount,
    required String paymentMethod,
    required String reference,
  }) {
    final newPayment = SubscriptionPayment(
      id: 'pay-${DateTime.now().millisecondsSinceEpoch}',
      date: DateTime.now(),
      amount: amount,
      paymentMethod: paymentMethod,
      reference: reference.isEmpty ? 'PAGO-AUTO' : reference,
      status: AppStatus.completed,
    );
    _payments.insert(0, newPayment);
    notifyListeners();
  }
}
