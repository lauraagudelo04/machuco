import 'package:flutter/foundation.dart';
import 'package:machuco/controllers/payment/payment_store.dart';
import 'package:machuco/models/payment/payment.dart';

class ClientPaymentController extends ChangeNotifier {
  ClientPaymentController({required this.clientId, PaymentStore? store})
    : _store = store ?? PaymentStore.shared {
    _store.addListener(_onStoreChanged);
  }

  final String clientId;
  final PaymentStore _store;

  List<PaymentRecord> get payments => List.unmodifiable(
    _store.payments.where((payment) => payment.clientId == clientId),
  );

  void _onStoreChanged() => notifyListeners();

  @override
  void dispose() {
    _store.removeListener(_onStoreChanged);
    super.dispose();
  }
}
