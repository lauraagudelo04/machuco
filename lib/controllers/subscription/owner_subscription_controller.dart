import 'package:flutter/foundation.dart';
import 'package:machuco/core/design_system/components/status_badge.dart';
import 'package:machuco/database/model/suscripcion/subscription.dart';
import 'package:machuco/database/repository/suscripcion/subscription_firestore_repository.dart';
import 'package:machuco/database/repository/suscripcion/subscription_repository.dart';
import 'package:machuco/service/subscription/subscription_preferences_service.dart';

/// Consulta la suscripción y registra exclusivamente sus propios pagos.
class OwnerSubscriptionController extends ChangeNotifier {
  OwnerSubscriptionController({
    SubscriptionRepository? repository,
    SubscriptionFirestoreRepository? firestoreRepository,
    SubscriptionPreferencesService? preferences,
    this.subscriptionId,
  }) : _repository = repository ?? SubscriptionRepository(),
       _firestoreRepository = firestoreRepository,
       _preferences = preferences ?? SubscriptionPreferencesService() {
    ready = load();
  }

  final SubscriptionRepository _repository;
  final SubscriptionFirestoreRepository? _firestoreRepository;
  final SubscriptionPreferencesService _preferences;
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
      _plans = await _repository.findPlans(
        includeDetails: _firestoreRepository != null,
      );
      final email = await _preferences.getUserEmail();
      final cloudData = _firestoreRepository == null ||
              email == null ||
              email.isEmpty
          ? null
          : await _firestoreRepository!.findByEmail(email, plans: _plans);
      final subscription = _firestoreRepository != null
          ? cloudData?.subscription
          : (subscriptionId == null
                ? (email == null || email.isEmpty
                      ? null
                      : await _repository.findSubscriptionByEmail(
                          email,
                          plans: _plans,
                        ))
                : await _repository.findSubscription(
                    subscriptionId,
                    plans: _plans,
                  ));
      final payments = _firestoreRepository != null
          ? (cloudData?.payments ?? <SubscriptionPayment>[])
          : (subscription == null
                ? <SubscriptionPayment>[]
                : await _repository.findPayments(subscription.id!));
      if (cloudData != null) {
        await _repository.cacheSubscription(cloudData.subscription);
        for (final payment in cloudData.payments) {
          await _repository.cachePayment(payment);
        }
        // Si la suscripción se construyó desde users.planId y el catálogo de
        // Supabase, este paso crea la copia completa en Firestore. Si ya
        // existía, actualiza la misma información sin cambiar su localId.
        if (_firestoreRepository != null) {
          await _syncToFirestore(cloudData.subscription, cloudData.payments);
        }
      }
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

  Future<List<SubscriptionPaymentMethod>> loadPaymentMethods() =>
      _repository.findPaymentMethods();

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
      // Se persiste primero en SQLite para conservar el mismo registro local.
      final savedPayment = await _saveLocalPayment(subscription, payment);
      // Actualiza el historial solo después de confirmar la escritura en SQLite.
      _payments = [savedPayment, ..._payments];
      // Luego se replica el mismo registro en la subcolección exclusiva de
      // pagos de suscripción, nunca en la colección raíz de reservas.
      if (_firestoreRepository != null) {
        await _syncToFirestore(subscription, _payments);
      }
    } finally {
      _isSaving = false;
      _notify();
    }
  }

  Future<SubscriptionPayment> _saveLocalPayment(
    SubscriptionDetails subscription,
    SubscriptionPayment payment,
  ) async {
    await _repository.saveSubscription(subscription);
    return _repository.savePayment(payment);
  }

  Future<void> _syncToFirestore(
    SubscriptionDetails subscription,
    List<SubscriptionPayment> payments,
  ) async {
    try {
      await _firestoreRepository!.sync(
        subscription: subscription,
        payments: payments,
      );
    } catch (error) {
      // La copia local ya está confirmada. Firestore puede reintentar sus
      // escrituras cuando vuelva la conexión.
      debugPrint('No se pudo sincronizar con Firestore: $error');
      throw StateError('No se pudo sincronizar el pago de suscripción.');
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
