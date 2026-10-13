import 'package:flutter/foundation.dart';
import 'package:machuco/core/design_system/components/status_badge.dart';
import 'package:machuco/database/model/suscripcion/subscription.dart';
import 'package:machuco/database/repository/suscripcion/subscription_repository.dart';

/// Consulta la suscripción y registra exclusivamente sus propios pagos.
class OwnerSubscriptionController extends ChangeNotifier {
  OwnerSubscriptionController({
    SubscriptionRepository? repository,
    this.subscriptionId,
  }) : _repository = repository ?? SubscriptionRepository() {
    ready = load();
  }

  final SubscriptionRepository _repository;
  final int? subscriptionId;
  late final Future<void> ready;
  SubscriptionDetails? _subscription;
  List<SubscriptionPayment> _payments = [];
  List<SubscriptionPlan> _plans = [];
  bool _isLoading = true;
  bool _isSaving = false;
  bool _disposed = false;
  String? _errorMessage;

  SubscriptionDetails? get subscription => _subscription;
  List<SubscriptionPayment> get payments => List.unmodifiable(_payments);
  List<SubscriptionPlan> get plans => List.unmodifiable(_plans);
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get errorMessage => _errorMessage;

  Future<void> load() async {
    _isLoading = true;
    _errorMessage = null;
    _subscription = null;
    _payments = [];
    _plans = [];
    _notify();
    try {
      _plans = await _repository.findPlans();
      final subscription = await _repository.findSubscription(
        subscriptionId,
        plans: _plans,
      );
      final payments = subscription == null
          ? <SubscriptionPayment>[]
          : await _repository.findPayments(subscription.id!);
      _subscription = subscription;
      _payments = payments;
    } on SubscriptionRepositoryException catch (error) {
      _errorMessage = error.message;
    } catch (_) {
      _errorMessage = 'No se pudo cargar la suscripción y su historial.';
    } finally {
      _isLoading = false;
      _notify();
    }
  }

  Future<void> addPayment({
    required int amount,
    required String paymentMethod,
    required String reference,
  }) async {
    if (_isLoading || _subscription == null) {
      throw StateError('La suscripción no está disponible');
    }
    if (_isSaving) throw StateError('Ya se está guardando un pago');
    final subscription = _subscription!;
    if (amount <= 0 ||
        paymentMethod.trim().isEmpty ||
        reference.trim().isEmpty) {
      throw ArgumentError('El monto, método y referencia deben ser válidos');
    }
    _isSaving = true;
    _notify();
    try {
      final now = DateTime.now();
      final payment = SubscriptionPayment(
        subscriptionId: subscription.id!,
        date: now,
        amount: amount,
        paymentMethod: paymentMethod.trim(),
        reference: reference.trim(),
        status: AppStatus.completed,
      );
      final savedPayment = await _repository.savePayment(payment);
      // Actualiza el historial solo después de confirmar la escritura en SQLite.
      _payments = [savedPayment, ..._payments];
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
