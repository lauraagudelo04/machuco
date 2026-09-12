import 'package:flutter/foundation.dart';
import 'package:machuco/controllers/payment/payment_store.dart';
import 'package:machuco/models/payment/payment.dart';

class OwnerPaymentController extends ChangeNotifier {
  OwnerPaymentController({required this.motelId, PaymentStore? store})
    : _store = store ?? PaymentStore.shared {
    _store.addListener(_onStoreChanged);
  }

  final String motelId;
  final PaymentStore _store;

  List<PaymentRecord> get payments => List.unmodifiable(
    _store.payments.where((payment) => payment.motelId == motelId),
  );

  List<PaymentRecord> get pendingPayments => List.unmodifiable(
    payments.where((payment) => payment.status == PaymentStatus.pending),
  );

  List<PaymentRecord> get completedPayments => List.unmodifiable(
    payments.where((payment) => payment.status != PaymentStatus.pending),
  );

  int get pendingAmount =>
      pendingPayments.fold(0, (total, payment) => total + payment.amount);

  List<FrequentClient> get frequentClients => List.unmodifiable(
    _store.frequentClients.where((client) => client.motelId == motelId),
  );

  MotelFinance? get finance =>
      _store.motelFinances.where((item) => item.motelId == motelId).firstOrNull;

  bool registerCashPayment(String paymentId) =>
      _store.registerCashPayment(paymentId);

  void _onStoreChanged() => notifyListeners();

  @override
  void dispose() {
    _store.removeListener(_onStoreChanged);
    super.dispose();
  }
}
