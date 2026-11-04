import 'package:flutter/foundation.dart';
import 'package:machuco/controllers/payment/payment_store.dart';
import 'package:machuco/models/payment/payment.dart';

class SystemAdminPaymentController extends ChangeNotifier {
  SystemAdminPaymentController({PaymentStore? store})
    : _store = store ?? PaymentStore.shared {
    _store.addListener(_onStoreChanged);
  }

  final PaymentStore _store;

  List<MotelFinance> get motelFinances => _store.motelFinances;

  int get totalIncome =>
      motelFinances.fold(0, (total, finance) => total + finance.income);

  int get totalPaymentsReceived => motelFinances.fold(
    0,
    (total, finance) => total + finance.paymentsReceived,
  );

  int get totalPendingAmount =>
      motelFinances.fold(0, (total, finance) => total + finance.pendingAmount);

  int get totalCommissions =>
      motelFinances.fold(0, (total, finance) => total + finance.commissions);

  void _onStoreChanged() => notifyListeners();

  @override
  void dispose() {
    _store.removeListener(_onStoreChanged);
    super.dispose();
  }
}
