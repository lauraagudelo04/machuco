import 'package:flutter/foundation.dart';
import 'package:machuco/controllers/payment/payment_store.dart';
import 'package:machuco/models/payment/payment.dart';
import 'package:machuco/models/payment/payment_catalog_entry.dart';
import 'package:machuco/repositories/payment/payment_repository.dart';

class OwnerPaymentController extends ChangeNotifier {
  OwnerPaymentController({
    required this.motelId,
    PaymentRepository? repository,
    PaymentStore? store,
    this.useDemoData = const bool.fromEnvironment('PAYMENT_USE_DEMO_DATA'),
  }) : _repository = repository ?? PaymentRepository(),
       _demoPayments = useDemoData
           ? (store ?? PaymentStore.shared).payments
           : const [] {
    ready = load();
  }

  final String motelId;
  final bool useDemoData;
  final PaymentRepository _repository;
  final List<PaymentRecord> _demoPayments;
  late final Future<void> ready;
  List<PaymentRecord> _payments = [];
  final Map<int, String> _methodNames = {};
  bool _isLoading = false;
  bool _isSaving = false;
  bool _disposed = false;
  String? _errorMessage;

  List<PaymentRecord> get payments => List.unmodifiable(_payments);
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get errorMessage => _errorMessage;

  List<PaymentRecord> get pendingPayments => List.unmodifiable(
    payments.where((payment) => payment.status == PaymentStatus.pending),
  );

  List<PaymentRecord> get completedPayments => List.unmodifiable(
    payments.where((payment) => payment.status == PaymentStatus.paid),
  );

  List<PaymentRecord> get otherPayments => List.unmodifiable(
    payments.where(
      (payment) =>
          payment.status == PaymentStatus.cancelled ||
          payment.status == PaymentStatus.refunded,
    ),
  );

  int get pendingAmount =>
      pendingPayments.fold(0, (total, payment) => total + payment.amount);

  int get totalIncome =>
      completedPayments.fold(0, (total, payment) => total + payment.amount);

  int get paymentsReceived => completedPayments.length;

  List<FrequentClient> get frequentClients {
    final clients = <String, List<PaymentRecord>>{};
    for (final payment in payments) {
      if (payment.status == PaymentStatus.cancelled) continue;
      (clients[payment.clientId] ??= []).add(payment);
    }
    final summaries = clients.entries.map((entry) {
      final records = entry.value;
      final name = records.first.client;
      final initials = name
          .trim()
          .split(RegExp(r'\s+'))
          .where((part) => part.isNotEmpty)
          .take(2)
          .map((part) => String.fromCharCode(part.runes.first))
          .join()
          .toUpperCase();
      return FrequentClient(
        clientId: entry.key,
        motelId: motelId,
        name: name,
        initials: initials,
        reservations: records
            .map((payment) => payment.bookingId)
            .toSet()
            .length,
        totalPaid: records
            .where((payment) => payment.status == PaymentStatus.paid)
            .fold(0, (total, payment) => total + payment.amount),
      );
    }).toList();
    summaries.sort((first, second) {
      final count = second.reservations.compareTo(first.reservations);
      return count == 0 ? first.name.compareTo(second.name) : count;
    });
    return List.unmodifiable(summaries);
  }

  String methodName(PaymentRecord payment) {
    final methodId = payment.paymentMethodId;
    if (methodId != null) return _methodNames[methodId] ?? 'Método #$methodId';
    return switch (payment.method) {
      PaymentMethod.cash => 'Efectivo',
      PaymentMethod.online => 'Pago en línea',
      null => 'Sin método registrado',
    };
  }

  Future<void> load() async {
    if (_isLoading || _isSaving || _disposed) return;
    _isLoading = true;
    _errorMessage = null;
    _notify();
    try {
      if (useDemoData) {
        await _repository.seedDemoPayments(
          motelId: motelId,
          payments: _demoPayments,
        );
      }
      final payments = await _repository.findPaymentsByMotel(motelId);
      final methods = await _repository.findCachedPaymentMethods();
      if (_disposed) return;
      _payments = payments;
      _methodNames.addEntries(
        methods.map((entry) => MapEntry(entry.id, entry.name)),
      );
    } on PaymentRepositoryException catch (error) {
      _errorMessage = error.message;
    } catch (_) {
      _errorMessage =
          'No se pudieron cargar los pagos del motel. Inténtalo nuevamente.';
    } finally {
      _isLoading = false;
      _notify();
    }
  }

  Future<List<PaymentCatalogEntry>> loadPaymentMethods() async {
    final methods = await _repository.findPaymentMethods();
    if (!_disposed) {
      _methodNames.addEntries(
        methods.map((entry) => MapEntry(entry.id, entry.name)),
      );
      _notify();
    }
    return methods;
  }

  Future<PaymentRecord> registerLocalPayment({
    required String paymentId,
    required int paymentMethodId,
  }) async {
    if (_isLoading || _isSaving || _disposed) {
      throw const PaymentRepositoryException(
        PaymentRepositoryError.invalidPayment,
        'Espera a que termine la operación de pagos actual.',
      );
    }
    _isSaving = true;
    _notify();
    try {
      final saved = await _repository.registerLocalPayment(
        paymentId: paymentId,
        motelId: motelId,
        paymentMethodId: paymentMethodId,
      );
      if (!_disposed) {
        _payments = [
          for (final payment in _payments)
            if (payment.id == saved.id) saved else payment,
        ];
      }
      return saved;
    } finally {
      _isSaving = false;
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
