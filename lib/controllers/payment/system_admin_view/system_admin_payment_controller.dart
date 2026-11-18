import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:machuco/models/payment/payment.dart';
import 'package:machuco/repositories/payment/payment_cloud_repository.dart';

/// Read-only platform totals, exclusively from server-confirmed payments.
class SystemAdminPaymentController extends ChangeNotifier {
  SystemAdminPaymentController({
    PlatformPaymentCloudRepository? repository,
    Stream<String?>? userChanges,
  }) : _repository = repository ?? FirestorePaymentCloudRepository() {
    _authSubscription =
        (userChanges ??
                FirebaseAuth.instance.userChanges().map((user) => user?.uid))
            .distinct()
            .listen(_onUserChanged);
  }

  final PlatformPaymentCloudRepository _repository;
  StreamSubscription<String?>? _authSubscription;
  StreamSubscription<PaymentCloudSnapshot>? _subscription;
  Timer? _confirmationTimer;
  String? _userId;
  int _generation = 0;
  bool _disposed = false;
  List<MotelFinance> _motelFinances = [];
  bool hasFinanceSnapshot = false;
  bool isFinanceCurrent = false;
  bool isLoading = false;
  String? errorMessage;

  List<MotelFinance> get motelFinances => List.unmodifiable(_motelFinances);
  int get totalIncome =>
      _motelFinances.fold(0, (sum, finance) => sum + finance.income);
  int get totalPaymentsReceived =>
      _motelFinances.fold(0, (sum, finance) => sum + finance.paymentsReceived);
  int get totalPendingAmount =>
      _motelFinances.fold(0, (sum, finance) => sum + finance.pendingAmount);
  int get totalRefundedAmount =>
      _motelFinances.fold(0, (sum, finance) => sum + finance.refundedAmount);

  void _onUserChanged(String? userId) {
    _userId = userId;
    _motelFinances = [];
    hasFinanceSnapshot = false;
    load();
  }

  void load() {
    if (_disposed) return;
    final generation = ++_generation;
    _subscription?.cancel();
    _confirmationTimer?.cancel();
    isFinanceCurrent = false;
    isLoading = _userId != null;
    errorMessage = _userId == null
        ? 'Inicia sesión como administrador para consultar las finanzas.'
        : null;
    notifyListeners();
    if (_userId == null) return;
    _confirmationTimer = Timer(const Duration(seconds: 12), () {
      if (_disposed || generation != _generation) return;
      isLoading = false;
      errorMessage =
          'Firebase no confirmó la conexión. Reintenta para verificar los saldos.';
      notifyListeners();
    });
    _subscription = _repository.watchPlatformPayments().listen(
      (snapshot) {
        if (_disposed || generation != _generation) return;
        if (!snapshot.isConfirmed) {
          isFinanceCurrent = false;
          errorMessage = hasFinanceSnapshot
              ? 'Se conserva la última consulta confirmada; conexión sin verificar.'
              : 'Esperando confirmación de Firebase. Los saldos no están disponibles.';
          notifyListeners();
          return;
        }
        _confirmationTimer?.cancel();
        _motelFinances = _aggregate(snapshot.payments);
        hasFinanceSnapshot = true;
        isFinanceCurrent = true;
        isLoading = false;
        errorMessage = null;
        notifyListeners();
      },
      onError: (Object error) {
        if (_disposed || generation != _generation) return;
        _confirmationTimer?.cancel();
        isLoading = false;
        isFinanceCurrent = false;
        errorMessage = error is PaymentCloudRepositoryException
            ? error.message
            : 'No se pudieron consultar las finanzas. Reintenta.';
        if (error is PaymentCloudRepositoryException &&
            error.type == PaymentCloudFailureType.permissionDenied) {
          _motelFinances = [];
          hasFinanceSnapshot = false;
        }
        notifyListeners();
      },
    );
  }

  List<MotelFinance> _aggregate(List<PaymentRecord> payments) {
    final groups = <String, List<PaymentRecord>>{};
    for (final payment in payments) {
      (groups[payment.motelId] ??= []).add(payment);
    }
    final result = groups.entries.map((entry) {
      final records = entry.value
        ..sort((a, b) => b.reservationDate.compareTo(a.reservationDate));
      int amount(PaymentStatus status) => records
          .where((payment) => payment.status == status)
          .fold(0, (sum, payment) => sum + payment.amount);
      return MotelFinance(
        motelId: entry.key,
        name: records.first.motel,
        // The payments collection is not a room inventory or commission ledger.
        rooms: 0,
        commissions: 0,
        income: amount(PaymentStatus.paid),
        paymentsReceived: records
            .where((payment) => payment.status == PaymentStatus.paid)
            .length,
        pendingAmount: amount(PaymentStatus.pending),
        refundedAmount: amount(PaymentStatus.refunded),
      );
    }).toList()..sort((a, b) => a.name.compareTo(b.name));
    return result;
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _confirmationTimer?.cancel();
    _subscription?.cancel();
    _authSubscription?.cancel();
    super.dispose();
  }
}
