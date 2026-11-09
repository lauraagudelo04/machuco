import 'package:flutter/foundation.dart';
import 'package:machuco/models/payment/payment.dart';

/// Store transitorio conservado para consumidores administrativos heredados.
///
/// Su instancia compartida inicia vacía: los fixtures fueron retirados para no
/// mezclarlos con la sincronización real del propietario.
class PaymentStore extends ChangeNotifier {
  PaymentStore._();

  /// Crea una fuente aislada con datos inyectados, útil para pruebas y para
  /// sustituir gradualmente el mock sin acoplar los controladores al singleton.
  factory PaymentStore.seeded({
    List<PaymentRecord> payments = const [],
    List<FrequentClient> frequentClients = const [],
    List<MotelFinance> motelFinances = const [],
  }) {
    final store = PaymentStore._();
    store._payments
      ..clear()
      ..addAll(payments);
    store._frequentClients
      ..clear()
      ..addAll(frequentClients);
    store._motelFinances
      ..clear()
      ..addAll(motelFinances);
    return store;
  }

  static const fallbackMotelId = '1';
  static final PaymentStore shared = PaymentStore._();

  final List<PaymentRecord> _payments = [];
  final List<FrequentClient> _frequentClients = [];
  final List<MotelFinance> _motelFinances = [];

  List<PaymentRecord> get payments => List.unmodifiable(_payments);
  List<FrequentClient> get frequentClients =>
      List.unmodifiable(_frequentClients);
  List<MotelFinance> get motelFinances => List.unmodifiable(_motelFinances);

  bool registerCashPayment(String paymentId) {
    final index = _payments.indexWhere((payment) => payment.id == paymentId);
    if (index == -1 || _payments[index].status != PaymentStatus.pending) {
      return false;
    }

    final payment = _payments[index];
    _payments[index] = payment.copyWith(
      status: PaymentStatus.paid,
      method: PaymentMethod.cash,
      paidAt: DateTime.now(),
      receiptNumber: 'CAJA-${payment.bookingReference}',
    );
    notifyListeners();
    return true;
  }
}
